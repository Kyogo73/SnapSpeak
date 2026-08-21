import Foundation
import SwiftData

@Model
public final class EntitlementCache {
    public var isPro: Bool
    public var expirationDate: Date?
    public var billingRetryExpired: Bool
    public var inGracePeriod: Bool
    public var updatedAt: Date

    public init(
        isPro: Bool,
        expirationDate: Date?,
        billingRetryExpired: Bool,
        inGracePeriod: Bool,
        updatedAt: Date
    ) {
        self.isPro = isPro
        self.expirationDate = expirationDate
        self.billingRetryExpired = billingRetryExpired
        self.inGracePeriod = inGracePeriod
        self.updatedAt = updatedAt
    }
}
