import ContentKit
import Foundation

public enum StoreProductID: Sendable {
    public static let monthly = "app.snapspeak.pro.monthly"
    public static let yearly = "app.snapspeak.pro.yearly"
    public static let all: Set<String> = [monthly, yearly]
}

public enum StoreLinks: Sendable {
    public static let terms = URL(string: "https://snapspeak.app/terms")
    public static let privacy = URL(string: "https://snapspeak.app/privacy")
}

public struct StoreOffering: Identifiable, Sendable, Equatable {
    public var id: String { productID }
    public var productID: String
    public var displayName: String
    public var displayPrice: String
    public var periodCode: String

    public init(productID: String, displayName: String, displayPrice: String, periodCode: String) {
        self.productID = productID
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.periodCode = periodCode
    }
}

public struct StoreSnapshot: Sendable, Equatable {
    public var resolver: EntitlementResolver
    public var offerings: [StoreOffering]

    public init(resolver: EntitlementResolver, offerings: [StoreOffering]) {
        self.resolver = resolver
        self.offerings = offerings
    }
}

public enum StorePurchaseOutcome: Sendable, Equatable {
    case success(productID: String)
    case cancelled
    case pending
    case failed(code: String)
}

struct PaywallRequest: Identifiable, Hashable {
    var id: String { reason }
    var reason: String
}
