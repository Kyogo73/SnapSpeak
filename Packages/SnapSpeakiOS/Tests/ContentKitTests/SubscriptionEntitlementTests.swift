import ContentKit
import Foundation
import Testing

@Suite("SubscriptionEntitlement")
struct SubscriptionEntitlementTests {
    private let now = Date(timeIntervalSince1970: 1_777_000_000)
    private var future: Date { now.addingTimeInterval(86_400) }
    private var past: Date { now.addingTimeInterval(-86_400) }

    @Test("revocation drops Pro regardless of status")
    func revocationDropsPro() {
        let verdict = SubscriptionEntitlement.evaluate(
            revocationDate: now,
            expirationDate: future,
            now: now,
            renewalState: .subscribed
        )
        #expect(verdict.isPro == false)
        #expect(verdict.inGracePeriod == false)
        #expect(verdict.billingRetryExpired == false)
    }

    @Test("grace period keeps Pro")
    func graceKeepsPro() {
        let verdict = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: past,
            now: now,
            renewalState: .inGracePeriod
        )
        #expect(verdict.isPro)
        #expect(verdict.inGracePeriod)
        #expect(verdict.billingRetryExpired == false)
    }

    @Test("billing retry after expiration drops Pro")
    func billingRetryExpiredDropsPro() {
        let verdict = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: past,
            now: now,
            renewalState: .inBillingRetryPeriod
        )
        #expect(verdict.isPro == false)
        #expect(verdict.billingRetryExpired)
    }

    @Test("billing retry before expiration keeps Pro")
    func billingRetryBeforeExpirationKeepsPro() {
        let verdict = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: future,
            now: now,
            renewalState: .inBillingRetryPeriod
        )
        #expect(verdict.isPro)
        #expect(verdict.billingRetryExpired == false)
    }

    @Test("missing status after expiration keeps Pro as grace")
    func missingStatusAfterExpirationKeepsGrace() {
        let verdict = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: past,
            now: now,
            renewalState: nil
        )
        #expect(verdict.isPro)
        #expect(verdict.inGracePeriod)
        #expect(verdict.billingRetryExpired == false)
    }

    @Test("missing status before expiration keeps Pro without grace")
    func missingStatusBeforeExpirationKeepsPro() {
        let verdict = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: future,
            now: now,
            renewalState: nil
        )
        #expect(verdict.isPro)
        #expect(verdict.inGracePeriod == false)
    }

    @Test("expired and revoked states drop Pro")
    func expiredAndRevokedDropPro() {
        let expired = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: past,
            now: now,
            renewalState: .expired
        )
        let revoked = SubscriptionEntitlement.evaluate(
            revocationDate: nil,
            expirationDate: past,
            now: now,
            renewalState: .revoked
        )
        #expect(expired.isPro == false)
        #expect(revoked.isPro == false)
    }
}
