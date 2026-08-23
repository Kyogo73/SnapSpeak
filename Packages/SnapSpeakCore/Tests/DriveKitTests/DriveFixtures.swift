import DriveKit
import Foundation
import SRSKit

enum DriveFixtures {
    static func composition(
        id: String,
        origin: DriveItem.Origin = .due,
        l1: String? = "こんにちは",
        l2: String = "Hello",
        audioPath: String? = nil,
        audioMs: Int? = nil,
        courseId: String = "course_a"
    ) -> DriveItem {
        DriveItem(
            courseId: courseId,
            itemId: id,
            skill: .composition,
            origin: origin,
            l1Text: l1,
            l2Text: l2,
            l1LanguageTag: "ja",
            l2LanguageTag: "en",
            audioRelativePath: audioPath,
            audioDurationMs: audioMs
        )
    }

    static func shadowing(
        id: String,
        origin: DriveItem.Origin = .due,
        l2: String = "Good morning",
        audioPath: String? = nil,
        audioMs: Int? = nil,
        courseId: String = "course_a"
    ) -> DriveItem {
        DriveItem(
            courseId: courseId,
            itemId: id,
            skill: .shadowing,
            origin: origin,
            l1Text: nil,
            l2Text: l2,
            l1LanguageTag: "ja",
            l2LanguageTag: "en",
            audioRelativePath: audioPath,
            audioDurationMs: audioMs
        )
    }

    /// 予算テスト用。ポーズと TTS を 0 にし、item 長を audioDurationMs だけで決める。
    static func measurableTiming(
        introMs: Int = 10_000,
        sectionMs: Int = 0,
        outroMs: Int = 10_000,
        itemGapMs: Int = 0,
        trackGapMs: Int = 0,
        maxPasses: Int = 300
    ) -> DriveTimingPolicy {
        DriveTimingPolicy(
            speakPauseFactor: 0,
            speakPauseClampMs: 0...0,
            repeatPauseFactor: 0,
            repeatPauseClampMs: 0...0,
            trackGapMs: trackGapMs,
            itemGapMs: itemGapMs,
            ttsBaseMs: 0,
            ttsMsPerCharL1: 0,
            ttsMsPerCharL2: 0,
            announceIntroMs: introMs,
            announceSectionMs: sectionMs,
            announceOutroMs: outroMs,
            maxUnrolledItemPasses: maxPasses
        )
    }

    static var onePassTiming: DriveTimingPolicy {
        var timing = DriveTimingPolicy.standard
        timing.maxUnrolledItemPasses = 1
        return timing
    }

    static var onePassStandard: DriveScriptSettings {
        DriveScriptSettings(timing: onePassTiming)
    }

    static func cappedTiming(_ maxPasses: Int) -> DriveTimingPolicy {
        var timing = DriveTimingPolicy.standard
        timing.maxUnrolledItemPasses = maxPasses
        return timing
    }

    static func settings(
        length: DriveScriptSettings.SessionLength = .minutes10,
        pauseMultiplier: Double = 1.0,
        repeats: Int = 2,
        timing: DriveTimingPolicy = .standard
    ) -> DriveScriptSettings {
        DriveScriptSettings(
            sessionLength: length,
            pauseMultiplier: pauseMultiplier,
            shadowingRepeats: repeats,
            timing: timing
        )
    }

    static func itemKinds(_ script: DriveScript) -> [DrivePhaseKind] {
        script.phases.map(\.kind)
    }

    static func itemRefs(_ script: DriveScript) -> [DriveItemRef] {
        var seen: [DriveItemRef] = []
        for phase in script.phases {
            guard let item = phase.item, seen.last != item else { continue }
            seen.append(item)
        }
        return seen
    }
}

extension DriveCursor {
    mutating func playThrough() -> [DriveCursor.Output] {
        var outputs = start()
        var guardCount = 0
        while guardCount < 10_000 {
            guardCount += 1
            let next = apply(.phaseFinished)
            outputs.append(contentsOf: next)
            if next.isEmpty { break }
            if next.contains(where: {
                if case .finished = $0 { return true }
                return false
            }) {
                break
            }
        }
        return outputs
    }

    static func completedRefs(in outputs: [DriveCursor.Output]) -> [DriveItemRef] {
        outputs.compactMap { output in
            if case let .itemCompleted(ref) = output { return ref }
            return nil
        }
    }
}
