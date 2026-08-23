import Foundation
import SRSKit

/// 決定的な純関数。乱数なし。入力順を保存する。
public enum DriveScriptBuilder {
    public static func build(items: [DriveItem], settings: DriveScriptSettings) -> DriveScript {
        let validated = validate(items)
        let valid = validated.valid
        let omitted = validated.omitted
        if valid.isEmpty {
            return DriveScript(
                phases: [],
                plannedTotalMs: 0,
                itemPassCount: 0,
                loops: false,
                omittedItemIds: omitted
            )
        }
        if settings.isEndless {
            return buildEndless(items: valid, omitted: omitted, settings: settings)
        }
        return buildBudgeted(items: valid, omitted: omitted, settings: settings)
    }

    private static func validate(_ items: [DriveItem]) -> (valid: [DriveItem], omitted: [String]) {
        var valid: [DriveItem] = []
        var omitted: [String] = []
        for item in items {
            if item.l2Text.isEmpty {
                omitted.append(item.itemId)
                continue
            }
            if item.skill == .composition && item.l1Text == nil {
                omitted.append(item.itemId)
                continue
            }
            valid.append(item)
        }
        return (valid, omitted)
    }

    private static func buildEndless(
        items: [DriveItem],
        omitted: [String],
        settings: DriveScriptSettings
    ) -> DriveScript {
        var phases: [DrivePhase] = []
        phases.append(introPhase(items: items, settings: settings))
        appendItemPass(into: &phases, items: items, passIndex: 0, includeSection: true, settings: settings)
        return DriveScript(
            phases: phases,
            plannedTotalMs: phases.reduce(0) { $0 + $1.estimatedDurationMs },
            itemPassCount: items.count,
            loops: true,
            omittedItemIds: omitted
        )
    }

    private struct PassPlan {
        var items: [DriveItem]
        var passIndex: Int
        var includeSection: Bool
    }

    private static func buildBudgeted(
        items: [DriveItem],
        omitted: [String],
        settings: DriveScriptSettings
    ) -> DriveScript {
        let timing = settings.timing
        let budget = settings.budgetMs
        let outroMs = timing.announceOutroMs
        var passes: [PassPlan] = []
        var usedMs = timing.announceIntroMs
        var unrolled = 0
        var passIndex = 0
        var firstPass = true

        while unrolled < timing.maxUnrolledItemPasses {
            var passItems: [DriveItem] = []
            for item in items {
                guard unrolled < timing.maxUnrolledItemPasses else { break }
                let extra = itemDurationMs(item, settings: settings)
                    + sectionCostMs(item: item, passItems: passItems, includeSection: firstPass, timing: timing)
                let projected = usedMs + extra + outroMs
                if !passes.isEmpty || !passItems.isEmpty, projected > budget {
                    break
                }
                passItems.append(item)
                usedMs += extra
                unrolled += 1
            }
            if passItems.isEmpty { break }
            passes.append(PassPlan(items: passItems, passIndex: passIndex, includeSection: firstPass))
            firstPass = false
            passIndex += 1
            if passItems.count < items.count { break }
        }

        var phases: [DrivePhase] = []
        phases.append(introPhase(items: items, settings: settings))
        for pass in passes {
            appendItemPass(
                into: &phases,
                items: pass.items,
                passIndex: pass.passIndex,
                includeSection: pass.includeSection,
                settings: settings
            )
        }
        phases.append(outroPhase(timing: timing))
        return DriveScript(
            phases: phases,
            plannedTotalMs: phases.reduce(0) { $0 + $1.estimatedDurationMs },
            itemPassCount: unrolled,
            loops: false,
            omittedItemIds: omitted
        )
    }

    private static func sectionCostMs(
        item: DriveItem,
        passItems: [DriveItem],
        includeSection: Bool,
        timing: DriveTimingPolicy
    ) -> Int {
        guard includeSection, shouldInsertSection(before: item, previous: passItems.last) else {
            return 0
        }
        return timing.announceSectionMs
    }

    private static func shouldInsertSection(before item: DriveItem, previous: DriveItem?) -> Bool {
        item.origin == .new && previous?.origin == .due
    }

    private static func introPhase(items: [DriveItem], settings: DriveScriptSettings) -> DrivePhase {
        let dueCount = items.filter { $0.origin == .due }.count
        let newCount = items.filter { $0.origin == .new }.count
        let isRepeatFill = items.contains { $0.origin == .repeatFill } && dueCount == 0 && newCount == 0
        return DrivePhase(
            kind: .sessionIntro,
            audio: .announcement(
                .sessionIntro(
                    dueCount: dueCount,
                    newCount: newCount,
                    isRepeatFill: isRepeatFill,
                    isEndless: settings.isEndless
                )
            ),
            estimatedDurationMs: settings.timing.announceIntroMs,
            item: nil
        )
    }

    private static func outroPhase(timing: DriveTimingPolicy) -> DrivePhase {
        DrivePhase(
            kind: .sessionOutro,
            audio: .announcement(.sessionOutro),
            estimatedDurationMs: timing.announceOutroMs,
            item: nil
        )
    }

    private static func appendItemPass(
        into phases: inout [DrivePhase],
        items: [DriveItem],
        passIndex: Int,
        includeSection: Bool,
        settings: DriveScriptSettings
    ) {
        var previous: DriveItem?
        for item in items {
            if includeSection, shouldInsertSection(before: item, previous: previous) {
                phases.append(
                    DrivePhase(
                        kind: .sectionAnnounce,
                        audio: .announcement(.newLessonSection),
                        estimatedDurationMs: settings.timing.announceSectionMs,
                        item: nil
                    )
                )
            }
            phases.append(contentsOf: itemPhases(item, passIndex: passIndex, settings: settings))
            previous = item
        }
    }

    static func itemDurationMs(_ item: DriveItem, settings: DriveScriptSettings) -> Int {
        itemPhases(item, passIndex: 0, settings: settings).reduce(0) { $0 + $1.estimatedDurationMs }
    }

    static func itemPhases(
        _ item: DriveItem,
        passIndex: Int,
        settings: DriveScriptSettings
    ) -> [DrivePhase] {
        let ref = DriveItemRef(
            courseId: item.courseId,
            itemId: item.itemId,
            skill: item.skill,
            passIndex: passIndex
        )
        switch item.skill {
        case .composition:
            return compositionPhases(item: item, ref: ref, settings: settings)
        case .shadowing:
            return shadowingPhases(item: item, ref: ref, settings: settings)
        }
    }

    private static func compositionPhases(
        item: DriveItem,
        ref: DriveItemRef,
        settings: DriveScriptSettings
    ) -> [DrivePhase] {
        let timing = settings.timing
        let l1 = item.l1Text ?? ""
        let answer = timing.answerMs(audioDurationMs: item.audioDurationMs, l2Text: item.l2Text)
        let promptMs = timing.ttsEstimateMs(text: l1, isL1: true)
        return [
            DrivePhase(
                kind: .promptL1,
                audio: .contentTTS(text: l1, languageTag: item.l1LanguageTag),
                estimatedDurationMs: promptMs,
                item: ref
            ),
            DrivePhase(
                kind: .speakPause,
                audio: .silence,
                estimatedDurationMs: timing.speakPauseMs(answerMs: answer, pauseMultiplier: settings.pauseMultiplier),
                item: ref
            ),
            DrivePhase(
                kind: .revealL2,
                audio: l2Audio(item),
                estimatedDurationMs: answer,
                item: ref
            ),
            DrivePhase(
                kind: .repeatPause,
                audio: .silence,
                estimatedDurationMs: timing.repeatPauseMs(answerMs: answer, pauseMultiplier: settings.pauseMultiplier),
                item: ref
            ),
            DrivePhase(
                kind: .itemGap,
                audio: .silence,
                estimatedDurationMs: timing.itemGapMs,
                item: ref
            ),
        ]
    }

    private static func shadowingPhases(
        item: DriveItem,
        ref: DriveItemRef,
        settings: DriveScriptSettings
    ) -> [DrivePhase] {
        let timing = settings.timing
        let answer = timing.answerMs(audioDurationMs: item.audioDurationMs, l2Text: item.l2Text)
        let repeats = settings.shadowingRepeats
        var phases: [DrivePhase] = []
        for index in 0..<repeats {
            phases.append(
                DrivePhase(
                    kind: .shadowTrack,
                    audio: l2Audio(item),
                    estimatedDurationMs: answer,
                    item: ref
                )
            )
            if index + 1 < repeats {
                phases.append(
                    DrivePhase(
                        kind: .trackGap,
                        audio: .silence,
                        estimatedDurationMs: timing.trackGapMs,
                        item: ref
                    )
                )
            }
        }
        phases.append(
            DrivePhase(
                kind: .itemGap,
                audio: .silence,
                estimatedDurationMs: timing.itemGapMs,
                item: ref
            )
        )
        return phases
    }

    private static func l2Audio(_ item: DriveItem) -> DrivePhaseAudio {
        if let path = item.audioRelativePath {
            return .file(
                courseId: item.courseId,
                relativePath: path,
                fallbackText: item.l2Text,
                fallbackLanguageTag: item.l2LanguageTag
            )
        }
        return .contentTTS(text: item.l2Text, languageTag: item.l2LanguageTag)
    }
}
