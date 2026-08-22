import Foundation

/// タイミング定数（ux-design §10.4 の初期仮値。テストで注入・将来校正）。
public struct DriveTimingPolicy: Sendable, Equatable {
    public var speakPauseFactor: Double
    public var speakPauseClampMs: ClosedRange<Int>
    public var repeatPauseFactor: Double
    public var repeatPauseClampMs: ClosedRange<Int>
    public var trackGapMs: Int
    public var itemGapMs: Int
    public var ttsBaseMs: Int
    public var ttsMsPerCharL1: Int
    public var ttsMsPerCharL2: Int
    public var announceIntroMs: Int
    public var announceSectionMs: Int
    public var announceOutroMs: Int
    /// 反復充填の暴走防止。
    public var maxUnrolledItemPasses: Int

    public init(
        speakPauseFactor: Double,
        speakPauseClampMs: ClosedRange<Int>,
        repeatPauseFactor: Double,
        repeatPauseClampMs: ClosedRange<Int>,
        trackGapMs: Int,
        itemGapMs: Int,
        ttsBaseMs: Int,
        ttsMsPerCharL1: Int,
        ttsMsPerCharL2: Int,
        announceIntroMs: Int,
        announceSectionMs: Int,
        announceOutroMs: Int,
        maxUnrolledItemPasses: Int
    ) {
        self.speakPauseFactor = speakPauseFactor
        self.speakPauseClampMs = speakPauseClampMs
        self.repeatPauseFactor = repeatPauseFactor
        self.repeatPauseClampMs = repeatPauseClampMs
        self.trackGapMs = trackGapMs
        self.itemGapMs = itemGapMs
        self.ttsBaseMs = ttsBaseMs
        self.ttsMsPerCharL1 = ttsMsPerCharL1
        self.ttsMsPerCharL2 = ttsMsPerCharL2
        self.announceIntroMs = announceIntroMs
        self.announceSectionMs = announceSectionMs
        self.announceOutroMs = announceOutroMs
        self.maxUnrolledItemPasses = maxUnrolledItemPasses
    }

    public static let standard = DriveTimingPolicy(
        speakPauseFactor: 1.6,
        speakPauseClampMs: 3_000...12_000,
        repeatPauseFactor: 1.0,
        repeatPauseClampMs: 2_000...8_000,
        trackGapMs: 800,
        itemGapMs: 1_200,
        ttsBaseMs: 500,
        ttsMsPerCharL1: 90,
        ttsMsPerCharL2: 60,
        announceIntroMs: 8_000,
        announceSectionMs: 2_500,
        announceOutroMs: 5_000,
        maxUnrolledItemPasses: 300
    )

    public func ttsEstimateMs(text: String, isL1: Bool) -> Int {
        let perChar = isL1 ? ttsMsPerCharL1 : ttsMsPerCharL2
        return ttsBaseMs + perChar * text.count
    }

    public func answerMs(audioDurationMs: Int?, l2Text: String) -> Int {
        audioDurationMs ?? ttsEstimateMs(text: l2Text, isL1: false)
    }

    public func speakPauseMs(answerMs: Int, pauseMultiplier: Double) -> Int {
        Self.clampedPause(
            answerMs: answerMs,
            factor: speakPauseFactor,
            multiplier: pauseMultiplier,
            clamp: speakPauseClampMs
        )
    }

    public func repeatPauseMs(answerMs: Int, pauseMultiplier: Double) -> Int {
        Self.clampedPause(
            answerMs: answerMs,
            factor: repeatPauseFactor,
            multiplier: pauseMultiplier,
            clamp: repeatPauseClampMs
        )
    }

    public static func clampedPause(
        answerMs: Int,
        factor: Double,
        multiplier: Double,
        clamp: ClosedRange<Int>
    ) -> Int {
        let raw = (Double(answerMs) * factor * multiplier).rounded()
        let value = Int(raw)
        return min(max(value, clamp.lowerBound), clamp.upperBound)
    }
}

public struct DriveScriptSettings: Sendable, Equatable {
    public enum SessionLength: Int, Sendable, Equatable, CaseIterable {
        case minutes5 = 5
        case minutes10 = 10
        case minutes20 = 20
        case endless = 0
    }

    public var sessionLength: SessionLength
    /// 0.8 / 1.0 / 1.3（Settings のプリセット写像）。
    public var pauseMultiplier: Double
    /// 1...3 にクランプ。
    public var shadowingRepeats: Int
    public var timing: DriveTimingPolicy

    public init(
        sessionLength: SessionLength = .minutes10,
        pauseMultiplier: Double = 1.0,
        shadowingRepeats: Int = 2,
        timing: DriveTimingPolicy = .standard
    ) {
        self.sessionLength = sessionLength
        self.pauseMultiplier = pauseMultiplier
        self.shadowingRepeats = min(max(shadowingRepeats, 1), 3)
        self.timing = timing
    }

    public static let standard = DriveScriptSettings()

    public var isEndless: Bool { sessionLength == .endless }

    /// エンドレスは 0。それ以外は分 × 60_000。
    public var budgetMs: Int {
        sessionLength.rawValue * 60_000
    }

    public var lengthCode: String {
        switch sessionLength {
        case .minutes5: return "5"
        case .minutes10: return "10"
        case .minutes20: return "20"
        case .endless: return "endless"
        }
    }
}
