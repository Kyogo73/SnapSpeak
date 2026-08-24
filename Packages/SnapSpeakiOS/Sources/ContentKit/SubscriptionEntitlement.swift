import Foundation

public enum EntitlementRenewalKind: Sendable, Equatable {
    case subscribed
    case inGracePeriod
    case inBillingRetryPeriod
    case expired
    case revoked
}

/// StoreKit の購読状態を Pro 判定に写す。StoreKit 型は持ち込まない。
public struct SubscriptionEntitlement: Sendable, Equatable {
    public var isPro: Bool
    public var expirationDate: Date?
    public var billingRetryExpired: Bool
    public var inGracePeriod: Bool

    public init(
        isPro: Bool,
        expirationDate: Date? = nil,
        billingRetryExpired: Bool = false,
        inGracePeriod: Bool = false
    ) {
        self.isPro = isPro
        self.expirationDate = expirationDate
        self.billingRetryExpired = billingRetryExpired
        self.inGracePeriod = inGracePeriod
    }

    /// `renewalState == nil` は status 取得失敗。verified な現行 entitlement は
    /// 期限切れ後も Pro を維持し、Grace とみなす（Billing Retry 期限切れは status があるときだけ落とす）。
    public static func evaluate(
        revocationDate: Date?,
        expirationDate: Date?,
        now: Date,
        renewalState: EntitlementRenewalKind?
    ) -> SubscriptionEntitlement {
        if revocationDate != nil {
            return SubscriptionEntitlement(isPro: false, expirationDate: expirationDate)
        }
        switch renewalState {
        case .subscribed:
            return SubscriptionEntitlement(isPro: true, expirationDate: expirationDate)
        case .inGracePeriod:
            return SubscriptionEntitlement(
                isPro: true,
                expirationDate: expirationDate,
                inGracePeriod: true
            )
        case .inBillingRetryPeriod:
            if let expirationDate, expirationDate > now {
                return SubscriptionEntitlement(isPro: true, expirationDate: expirationDate)
            }
            return SubscriptionEntitlement(
                isPro: false,
                expirationDate: expirationDate,
                billingRetryExpired: true
            )
        case .expired, .revoked:
            return SubscriptionEntitlement(isPro: false, expirationDate: expirationDate)
        case nil:
            if let expirationDate, expirationDate <= now {
                return SubscriptionEntitlement(
                    isPro: true,
                    expirationDate: expirationDate,
                    inGracePeriod: true
                )
            }
            return SubscriptionEntitlement(isPro: true, expirationDate: expirationDate)
        }
    }
}
