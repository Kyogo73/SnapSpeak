import Foundation
import SRSKit

/// アナウンスは意味だけを持つ。文言は iOS 側が String Catalog から解決する。
public enum DriveAnnouncement: Sendable, Equatable, Hashable {
    case sessionIntro(dueCount: Int, newCount: Int, isRepeatFill: Bool, isEndless: Bool)
    case newLessonSection
    /// 完了数は実行時にしか分からないため実行側が整形する。
    case sessionOutro
}

public enum DrivePhaseKind: String, Sendable, Equatable {
    case sessionIntro
    case sectionAnnounce
    case promptL1
    case speakPause
    case revealL2
    case repeatPause
    case shadowTrack
    case trackGap
    case itemGap
    case sessionOutro
}

public enum DrivePhaseAudio: Sendable, Equatable {
    case announcement(DriveAnnouncement)
    case contentTTS(text: String, languageTag: String)
    case file(
        courseId: String,
        relativePath: String,
        fallbackText: String,
        fallbackLanguageTag: String
    )
    case silence
}

public struct DrivePhase: Sendable, Equatable {
    public var kind: DrivePhaseKind
    public var audio: DrivePhaseAudio
    public var estimatedDurationMs: Int
    /// アナウンス系は nil。
    public var item: DriveItemRef?

    public init(
        kind: DrivePhaseKind,
        audio: DrivePhaseAudio,
        estimatedDurationMs: Int,
        item: DriveItemRef?
    ) {
        self.kind = kind
        self.audio = audio
        self.estimatedDurationMs = estimatedDurationMs
        self.item = item
    }
}

public struct DriveScript: Sendable, Equatable {
    public var phases: [DrivePhase]
    public var plannedTotalMs: Int
    /// 完走した場合の完了数（= itemCompleted の総数）。
    public var itemPassCount: Int
    /// endless のとき true（phases は 1 周分のみ）。
    public var loops: Bool
    /// 生成不能で落とした Item（例: composition の l1Text 欠落）。
    public var omittedItemIds: [String]

    public init(
        phases: [DrivePhase],
        plannedTotalMs: Int,
        itemPassCount: Int,
        loops: Bool,
        omittedItemIds: [String]
    ) {
        self.phases = phases
        self.plannedTotalMs = plannedTotalMs
        self.itemPassCount = itemPassCount
        self.loops = loops
        self.omittedItemIds = omittedItemIds
    }
}
