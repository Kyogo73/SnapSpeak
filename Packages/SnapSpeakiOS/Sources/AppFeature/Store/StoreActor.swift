import ContentKit
import Foundation
import Persistence
import StoreKit

/// Single StoreKit 2 owner. Verified transactions only. Always `finish()` updates.
public actor StoreActor {
    private let persistence: PersistenceActor
    private var products: [Product] = []
    private var isPro = false
    private var storeAvailable = false
    private var compositionsUsedToday = 0
    private var expirationDate: Date?
    private var billingRetryExpired = false
    private var inGracePeriod = false
    private var updatesTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<StoreSnapshot>.Continuation] = [:]

    public init(persistence: PersistenceActor) {
        self.persistence = persistence
    }

    public func currentSnapshot() -> StoreSnapshot {
        makeSnapshot()
    }

    public func snapshots() -> AsyncStream<StoreSnapshot> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(makeSnapshot())
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id) }
            }
        }
    }

    public func start() async {
        await applyCachedEntitlement()
        await loadProducts()
        await refreshEntitlements()
        listenForUpdates()
    }

    public func updateCompositionsUsedToday(_ count: Int) {
        compositionsUsedToday = count
        publish()
    }

    public func purchase(productID: String) async -> StorePurchaseOutcome {
        guard let product = products.first(where: { $0.id == productID }) else {
            return .failed(code: "product_unavailable")
        }
        do {
            let result = try await product.purchase()
            return await handlePurchaseResult(result, productID: productID)
        } catch {
            return .failed(code: Self.errorCode(error))
        }
    }

    public func restore() async -> StorePurchaseOutcome {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return .success(productID: "restored")
        } catch {
            return .failed(code: Self.errorCode(error))
        }
    }

    private func handlePurchaseResult(
        _ result: Product.PurchaseResult,
        productID: String
    ) async -> StorePurchaseOutcome {
        switch result {
        case let .success(verification):
            switch verification {
            case let .verified(transaction):
                await refreshEntitlements()
                await transaction.finish()
                return .success(productID: productID)
            case let .unverified(transaction, _):
                await transaction.finish()
                return .failed(code: "unverified")
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed(code: "unknown")
        }
    }

    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: StoreProductID.all)
            products = loaded.sorted { lhs, rhs in
                if lhs.id == StoreProductID.yearly { return true }
                if rhs.id == StoreProductID.yearly { return false }
                return lhs.id < rhs.id
            }
            storeAvailable = !loaded.isEmpty
        } catch {
            products = []
            storeAvailable = false
        }
        publish()
    }

    private func refreshEntitlements() async {
        var foundPro = false
        var expiration: Date?
        var grace = false
        var retryExpired = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard StoreProductID.all.contains(transaction.productID) else { continue }
            let verdict = await evaluate(transaction)
            if verdict.isPro { foundPro = true }
            if verdict.inGracePeriod { grace = true }
            if verdict.billingRetryExpired { retryExpired = true }
            if let date = verdict.expirationDate { expiration = date }
        }

        isPro = foundPro
        expirationDate = expiration
        inGracePeriod = grace
        billingRetryExpired = retryExpired && !foundPro
        persistCache()
        publish()
    }

    private func evaluate(_ transaction: Transaction) async -> (
        isPro: Bool,
        expirationDate: Date?,
        billingRetryExpired: Bool,
        inGracePeriod: Bool
    ) {
        if transaction.revocationDate != nil {
            return (false, transaction.expirationDate, false, false)
        }
        if let status = await subscriptionStatus(for: transaction) {
            switch status.state {
            case .subscribed:
                return (true, transaction.expirationDate, false, false)
            case .inGracePeriod:
                return (true, transaction.expirationDate, false, true)
            case .inBillingRetryPeriod:
                if let expiration = transaction.expirationDate, expiration > Date() {
                    return (true, expiration, false, false)
                }
                return (false, transaction.expirationDate, true, false)
            case .expired, .revoked:
                return (false, transaction.expirationDate, false, false)
            default:
                return (false, transaction.expirationDate, false, false)
            }
        }
        if let expiration = transaction.expirationDate {
            return (expiration > Date(), expiration, false, false)
        }
        return (true, nil, false, false)
    }

    private func subscriptionStatus(
        for transaction: Transaction
    ) async -> Product.SubscriptionInfo.Status? {
        let product = products.first { $0.id == transaction.productID }
            ?? (try? await Product.products(for: [transaction.productID]).first)
        guard let statuses = try? await product?.subscription?.status else { return nil }
        return statuses.first { status in
            if case let .verified(statusTransaction) = status.transaction {
                return statusTransaction.originalID == transaction.originalID
            }
            return false
        } ?? statuses.first
    }

    private func listenForUpdates() {
        updatesTask?.cancel()
        updatesTask = Task {
            for await result in Transaction.updates {
                switch result {
                case let .verified(transaction):
                    await refreshEntitlements()
                    await transaction.finish()
                case let .unverified(transaction, _):
                    await transaction.finish()
                }
            }
        }
    }

    private func applyCachedEntitlement() async {
        guard let cache = try? await persistence.loadEntitlementCache() else { return }
        isPro = cache.isPro && !cache.billingRetryExpired
        if cache.inGracePeriod { isPro = true }
        if cache.billingRetryExpired { isPro = false }
        expirationDate = cache.expirationDate
        inGracePeriod = cache.inGracePeriod
        billingRetryExpired = cache.billingRetryExpired
        publish()
    }

    private func persistCache() {
        let dto = EntitlementCacheDTO(
            isPro: isPro,
            expirationDate: expirationDate,
            billingRetryExpired: billingRetryExpired,
            inGracePeriod: inGracePeriod,
            updatedAt: Date()
        )
        Task { try? await persistence.upsertEntitlementCache(dto) }
    }

    private func makeSnapshot() -> StoreSnapshot {
        StoreSnapshot(
            resolver: EntitlementResolver(
                isPro: isPro,
                storeAvailable: storeAvailable,
                compositionsUsedToday: compositionsUsedToday
            ),
            offerings: products.map(Self.offering(from:))
        )
    }

    private func publish() {
        let snapshot = makeSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private static func offering(from product: Product) -> StoreOffering {
        let period: String
        if let unit = product.subscription?.subscriptionPeriod.unit {
            switch unit {
            case .year: period = "year"
            case .month: period = "month"
            case .week: period = "week"
            case .day: period = "day"
            @unknown default: period = "period"
            }
        } else {
            period = "period"
        }
        return StoreOffering(
            productID: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            periodCode: period
        )
    }

    private static func errorCode(_ error: Error) -> String {
        if let storeError = error as? StoreKitError {
            switch storeError {
            case .networkError: return "network"
            case .systemError: return "system"
            case .userCancelled: return "cancelled"
            case .notAvailableInStorefront: return "storefront"
            case .notEntitled: return "not_entitled"
            default: return "storekit"
            }
        }
        return "error_\((error as NSError).code)"
    }
}
