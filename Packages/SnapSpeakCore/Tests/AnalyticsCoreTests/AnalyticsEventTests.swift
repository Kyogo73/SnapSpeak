import AnalyticsCore
import Testing

@Test func driveSessionEventsCarryCodesOnly() {
    let started = AnalyticsEvent.driveSessionStarted(dueCount: 3, newCount: 1, lengthCode: "10")
    let completed = AnalyticsEvent.driveSessionCompleted(
        completedCount: 4,
        durationBand: Quantization.durationBand(ms: 12_000),
        endReason: "finished",
        usedTTSFallback: true
    )
    let note = AnalyticsEvent.driveNoteOpened(completedCount: 4)

    #expect(started == .driveSessionStarted(dueCount: 3, newCount: 1, lengthCode: "10"))
    #expect(started != .driveSessionStarted(dueCount: 3, newCount: 1, lengthCode: "endless"))
    #expect(completed == .driveSessionCompleted(
        completedCount: 4,
        durationBand: "5-15s",
        endReason: "finished",
        usedTTSFallback: true
    ))
    #expect(completed != .driveSessionCompleted(
        completedCount: 4,
        durationBand: "5-15s",
        endReason: "stopped",
        usedTTSFallback: true
    ))
    #expect(note == .driveNoteOpened(completedCount: 4))
    #expect(note != .driveNoteOpened(completedCount: 0))
}

@Test func paywallEventsCarryCodesOnly() {
    let shown = AnalyticsEvent.paywallShown(reason: "catalog")
    let succeeded = AnalyticsEvent.purchaseSucceeded(productId: "app.snapspeak.pro.monthly")
    let failed = AnalyticsEvent.purchaseFailed(code: "payment_cancelled")
    let limit = AnalyticsEvent.limitReached(kind: "composition")

    #expect(shown == .paywallShown(reason: "catalog"))
    #expect(shown != .paywallShown(reason: "review"))
    #expect(succeeded == .purchaseSucceeded(productId: "app.snapspeak.pro.monthly"))
    #expect(succeeded != .purchaseSucceeded(productId: "app.snapspeak.pro.yearly"))
    #expect(failed == .purchaseFailed(code: "payment_cancelled"))
    #expect(failed != .purchaseFailed(code: "unknown"))
    #expect(limit == .limitReached(kind: "composition"))
    #expect(limit != .limitReached(kind: "unit"))
}
