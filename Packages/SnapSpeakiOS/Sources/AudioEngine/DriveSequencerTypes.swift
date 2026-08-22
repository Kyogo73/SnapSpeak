import DriveKit
import Foundation

public enum DrivePauseReason: Sendable, Equatable {
    case user
    case interruption
    case routeChange
    case mediaServicesReset
    case audioSessionFailure
}

public enum DriveSequencerEvent: Sendable, Equatable {
    case phaseChanged(kind: DrivePhaseKind, itemRef: DriveItemRef?)
    case itemCompleted(DriveItemRef, usedTTSFallback: Bool, elapsedMs: Int)
    case itemSkipped(DriveItemRef)
    case paused(reason: DrivePauseReason)
    case resumed
    case finished(endedByUser: Bool, completedCount: Int)
}

public protocol DriveSequencing: Sendable {
    // actor 実装が満たせるよう async 要件にする（同期要件は actor 分離と両立しない）
    func events() async -> AsyncStream<DriveSequencerEvent>
    func start(
        script: DriveScript,
        announcementTexts: [DriveAnnouncement: String],
        outroText: @escaping @Sendable (Int) -> String,
        assets: (any DriveAssetResolving)?
    ) async
    func pause() async
    func resume() async
    func skipForward() async
    func skipBackward() async
    func stop() async
}
