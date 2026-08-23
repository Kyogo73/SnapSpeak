import DriveKit
import Foundation
import SRSKit
import Testing

@Suite("DriveScriptBuilder")
struct DriveScriptBuilderTests {
    @Test("B1 空 items → phases 空・itemPassCount 0・loops false")
    func emptyItems() {
        let script = DriveScriptBuilder.build(items: [], settings: .standard)
        #expect(script.phases.isEmpty)
        #expect(script.itemPassCount == 0)
        #expect(script.loops == false)
        #expect(script.plannedTotalMs == 0)
        #expect(script.omittedItemIds.isEmpty)
    }

    @Test("B2 composition 1 件の標準フェーズ列（intro / outro 含む）")
    func compositionStandardPhases() {
        let item = DriveFixtures.composition(id: "c1", origin: .due)
        let script = DriveScriptBuilder.build(items: [item], settings: DriveFixtures.onePassStandard)
        let kinds = DriveFixtures.itemKinds(script)
        #expect(kinds == [
            .sessionIntro, .promptL1, .speakPause, .revealL2, .repeatPause, .itemGap, .sessionOutro,
        ])
        #expect(script.itemPassCount == 1)
        #expect(script.loops == false)

        let ref = DriveItemRef(courseId: "course_a", itemId: "c1", skill: .composition, passIndex: 0)
        #expect(script.phases[0].item == nil)
        #expect(script.phases[1].item == ref)
        #expect(script.phases[5].item == ref)
        #expect(script.phases[6].item == nil)

        if case let .announcement(ann) = script.phases[0].audio {
            #expect(ann == .sessionIntro(dueCount: 1, newCount: 0, isRepeatFill: false, isEndless: false))
        } else {
            Issue.record("intro audio")
        }
        if case let .contentTTS(text, tag) = script.phases[1].audio {
            #expect(text == "こんにちは")
            #expect(tag == "ja")
        } else {
            Issue.record("prompt audio")
        }
        #expect(script.phases[2].audio == .silence)
        if case let .contentTTS(text, tag) = script.phases[3].audio {
            #expect(text == "Hello")
            #expect(tag == "en")
        } else {
            Issue.record("reveal audio")
        }
        #expect(script.phases[6].audio == .announcement(.sessionOutro))
        #expect(script.plannedTotalMs == script.phases.reduce(0) { $0 + $1.estimatedDurationMs })
    }

    @Test("B3 shadowing repeats = 1 / 2 / 3 のフェーズ数と trackGap 位置")
    func shadowingRepeats() {
        let item = DriveFixtures.shadowing(id: "s1")
        let one = DriveScriptBuilder.build(
            items: [item],
            settings: DriveFixtures.settings(repeats: 1, timing: DriveFixtures.onePassTiming)
        )
        #expect(DriveFixtures.itemKinds(one) == [
            .sessionIntro, .shadowTrack, .itemGap, .sessionOutro,
        ])

        let two = DriveScriptBuilder.build(
            items: [item],
            settings: DriveFixtures.settings(repeats: 2, timing: DriveFixtures.onePassTiming)
        )
        #expect(DriveFixtures.itemKinds(two) == [
            .sessionIntro, .shadowTrack, .trackGap, .shadowTrack, .itemGap, .sessionOutro,
        ])

        let three = DriveScriptBuilder.build(
            items: [item],
            settings: DriveFixtures.settings(repeats: 3, timing: DriveFixtures.onePassTiming)
        )
        #expect(DriveFixtures.itemKinds(three) == [
            .sessionIntro, .shadowTrack, .trackGap, .shadowTrack, .trackGap, .shadowTrack, .itemGap,
            .sessionOutro,
        ])
    }

    @Test("B4 audioDurationMs ありは answerMs に採用 / なしは TTS 推定（L1/L2 係数）")
    func answerMsSource() {
        let timed = DriveFixtures.composition(id: "c1", l1: "あい", l2: "Hi", audioMs: 4_000)
        let untimed = DriveFixtures.composition(id: "c2", l1: "あい", l2: "Hi")
        let scriptTimed = DriveScriptBuilder.build(items: [timed], settings: .standard)
        let scriptUntimed = DriveScriptBuilder.build(items: [untimed], settings: .standard)

        let revealTimed = scriptTimed.phases.first { $0.kind == .revealL2 }
        let revealUntimed = scriptUntimed.phases.first { $0.kind == .revealL2 }
        #expect(revealTimed?.estimatedDurationMs == 4_000)
        let expectedL2 = DriveTimingPolicy.standard.ttsEstimateMs(text: "Hi", isL1: false)
        #expect(revealUntimed?.estimatedDurationMs == expectedL2)

        let prompt = scriptUntimed.phases.first { $0.kind == .promptL1 }
        let expectedL1 = DriveTimingPolicy.standard.ttsEstimateMs(text: "あい", isL1: true)
        #expect(prompt?.estimatedDurationMs == expectedL1)
        #expect(expectedL1 != expectedL2)
    }

    @Test("B5 speakPause クランプと pauseMultiplier 0.8 / 1.3")
    func speakPauseClampAndMultiplier() {
        let short = DriveFixtures.composition(id: "short", l1: "あ", l2: "A")
        let long = DriveFixtures.composition(id: "long", l1: "あ", l2: "A", audioMs: 20_000)
        let shortScript = DriveScriptBuilder.build(items: [short], settings: .standard)
        let longScript = DriveScriptBuilder.build(items: [long], settings: .standard)
        let shortPause = shortScript.phases.first { $0.kind == .speakPause }?.estimatedDurationMs
        let longPause = longScript.phases.first { $0.kind == .speakPause }?.estimatedDurationMs
        #expect(shortPause == 3_000)
        #expect(longPause == 12_000)

        let mid = DriveFixtures.composition(id: "mid", l1: "あ", l2: "A", audioMs: 4_000)
        let standard = DriveScriptBuilder.build(items: [mid], settings: DriveFixtures.settings())
        let shortMul = DriveScriptBuilder.build(
            items: [mid],
            settings: DriveFixtures.settings(pauseMultiplier: 0.8)
        )
        let longMul = DriveScriptBuilder.build(
            items: [mid],
            settings: DriveFixtures.settings(pauseMultiplier: 1.3)
        )
        let standardMs = standard.phases.first { $0.kind == .speakPause }?.estimatedDurationMs
        let shortMs = shortMul.phases.first { $0.kind == .speakPause }?.estimatedDurationMs
        let longMs = longMul.phases.first { $0.kind == .speakPause }?.estimatedDurationMs
        #expect(standardMs == 6_400)
        #expect(shortMs == 5_120)
        #expect(longMs == 8_320)
    }

    @Test("repeatPause クランプと pauseMultiplier 0.8 / 1.3")
    func repeatPauseClampAndMultiplier() {
        let short = DriveFixtures.composition(id: "short", l1: "あ", l2: "A")
        let long = DriveFixtures.composition(id: "long", l1: "あ", l2: "A", audioMs: 20_000)
        let shortScript = DriveScriptBuilder.build(items: [short], settings: .standard)
        let longScript = DriveScriptBuilder.build(items: [long], settings: .standard)
        let shortPause = shortScript.phases.first { $0.kind == .repeatPause }?.estimatedDurationMs
        let longPause = longScript.phases.first { $0.kind == .repeatPause }?.estimatedDurationMs
        #expect(shortPause == 2_000)
        #expect(longPause == 8_000)

        let mid = DriveFixtures.composition(id: "mid", l1: "あ", l2: "A", audioMs: 4_000)
        let standard = DriveScriptBuilder.build(items: [mid], settings: DriveFixtures.settings())
        let shortMul = DriveScriptBuilder.build(
            items: [mid],
            settings: DriveFixtures.settings(pauseMultiplier: 0.8)
        )
        let longMul = DriveScriptBuilder.build(
            items: [mid],
            settings: DriveFixtures.settings(pauseMultiplier: 1.3)
        )
        let standardMs = standard.phases.first { $0.kind == .repeatPause }?.estimatedDurationMs
        let shortMs = shortMul.phases.first { $0.kind == .repeatPause }?.estimatedDurationMs
        let longMs = longMul.phases.first { $0.kind == .repeatPause }?.estimatedDurationMs
        #expect(standardMs == 4_000)
        #expect(shortMs == 3_200)
        #expect(longMs == 5_200)
    }

    @Test("B6 切り詰め: 予算ちょうど / 1ms 不足 / 先頭超過でも 1 件")
    func truncationBoundaries() {
        let timing = DriveFixtures.measurableTiming()
        let exact = [
            DriveFixtures.composition(id: "a", audioMs: 140_000),
            DriveFixtures.composition(id: "b", audioMs: 140_000),
        ]
        let exactScript = DriveScriptBuilder.build(
            items: exact,
            settings: DriveFixtures.settings(length: .minutes5, timing: timing)
        )
        #expect(exactScript.itemPassCount == 2)
        #expect(exactScript.plannedTotalMs == 300_000)

        let shortOne = [
            DriveFixtures.composition(id: "a", audioMs: 140_000),
            DriveFixtures.composition(id: "b", audioMs: 140_001),
        ]
        let shortScript = DriveScriptBuilder.build(
            items: shortOne,
            settings: DriveFixtures.settings(length: .minutes5, timing: timing)
        )
        #expect(shortScript.itemPassCount == 1)
        #expect(DriveFixtures.itemRefs(shortScript).map(\.itemId) == ["a"])

        let oversized = [DriveFixtures.composition(id: "huge", audioMs: 400_000)]
        let overScript = DriveScriptBuilder.build(
            items: oversized,
            settings: DriveFixtures.settings(length: .minutes5, timing: timing)
        )
        #expect(overScript.itemPassCount == 1)
        #expect(DriveFixtures.itemRefs(overScript).map(\.itemId) == ["huge"])
    }

    @Test("B7 反復充填: passIndex 増加・sectionAnnounce は 1 周目のみ・上限")
    func repeatFillAndCap() {
        let timing = DriveFixtures.measurableTiming(maxPasses: 5)
        let items = [
            DriveFixtures.composition(id: "due1", origin: .due, audioMs: 20_000),
            DriveFixtures.composition(id: "new1", origin: .new, l1: "次", l2: "Next", audioMs: 20_000),
        ]
        let script = DriveScriptBuilder.build(
            items: items,
            settings: DriveFixtures.settings(length: .minutes5, timing: timing)
        )
        let refs = DriveFixtures.itemRefs(script)
        #expect(refs.count == 5)
        #expect(refs.map(\.passIndex) == [0, 0, 1, 1, 2])
        #expect(refs.map(\.itemId) == ["due1", "new1", "due1", "new1", "due1"])
        let sections = script.phases.filter { $0.kind == .sectionAnnounce }
        #expect(sections.count == 1)
    }

    @Test("B8 endless: loops true・1 周のみ・outro なし")
    func endlessOneLoop() {
        let items = [
            DriveFixtures.composition(id: "a"),
            DriveFixtures.composition(id: "b", origin: .new),
        ]
        let script = DriveScriptBuilder.build(
            items: items,
            settings: DriveFixtures.settings(length: .endless)
        )
        #expect(script.loops == true)
        #expect(script.itemPassCount == 2)
        #expect(script.phases.contains { $0.kind == .sessionOutro } == false)
        #expect(DriveFixtures.itemRefs(script).map(\.passIndex) == [0, 0])
        #expect(script.phases.first?.kind == .sessionIntro)
    }

    @Test("B9 composition の l1 欠落 / l2 空 → omitted に入り phases に出ない")
    func omittedInvalidItems() {
        let items = [
            DriveFixtures.composition(id: "no_l1", l1: nil),
            DriveFixtures.composition(id: "empty_l2", l2: ""),
            DriveFixtures.composition(id: "ok"),
        ]
        let script = DriveScriptBuilder.build(items: items, settings: DriveFixtures.onePassStandard)
        #expect(script.omittedItemIds == ["no_l1", "empty_l2"])
        #expect(DriveFixtures.itemRefs(script).map(\.itemId) == ["ok"])
    }

    @Test("B10 due→new 境界の sectionAnnounce と intro パラメータ")
    func introAndSectionAnnounce() {
        let mixed = [
            DriveFixtures.composition(id: "d1", origin: .due),
            DriveFixtures.composition(id: "d2", origin: .due),
            DriveFixtures.composition(id: "n1", origin: .new),
        ]
        let mixedScript = DriveScriptBuilder.build(items: mixed, settings: .standard)
        let sectionIndexes = mixedScript.phases.indices.filter { mixedScript.phases[$0].kind == .sectionAnnounce }
        #expect(sectionIndexes.count == 1)
        if let index = sectionIndexes.first {
            #expect(mixedScript.phases[index + 1].item?.itemId == "n1")
        }
        #expect(intro(of: mixedScript) == .sessionIntro(
            dueCount: 2, newCount: 1, isRepeatFill: false, isEndless: false
        ))

        let dueOnly = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "d", origin: .due)],
            settings: .standard
        )
        #expect(intro(of: dueOnly) == .sessionIntro(
            dueCount: 1, newCount: 0, isRepeatFill: false, isEndless: false
        ))
        #expect(dueOnly.phases.contains { $0.kind == .sectionAnnounce } == false)

        let newOnly = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "n", origin: .new)],
            settings: .standard
        )
        #expect(intro(of: newOnly) == .sessionIntro(
            dueCount: 0, newCount: 1, isRepeatFill: false, isEndless: false
        ))

        let fillOnly = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "r", origin: .repeatFill)],
            settings: .standard
        )
        #expect(intro(of: fillOnly) == .sessionIntro(
            dueCount: 0, newCount: 0, isRepeatFill: true, isEndless: false
        ))

        let endless = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "e")],
            settings: DriveFixtures.settings(length: .endless)
        )
        #expect(intro(of: endless) == .sessionIntro(
            dueCount: 1, newCount: 0, isRepeatFill: false, isEndless: true
        ))
    }

    @Test("B11 同一入力 2 回で DriveScript が等価")
    func deterministic() {
        let items = [
            DriveFixtures.composition(id: "d", origin: .due, audioPath: "a.m4a", audioMs: 1_200),
            DriveFixtures.shadowing(id: "s", origin: .new, audioMs: 800),
        ]
        let settings = DriveFixtures.settings(length: .minutes5, pauseMultiplier: 1.3, repeats: 3)
        let first = DriveScriptBuilder.build(items: items, settings: settings)
        let second = DriveScriptBuilder.build(items: items, settings: settings)
        #expect(first == second)
    }

    @Test("audioRelativePath ありは file（fallback 同梱）、なしは contentTTS")
    func fileVersusTTS() {
        let withFile = DriveFixtures.composition(id: "f", audioPath: "audio/f.m4a", audioMs: 1_000)
        let script = DriveScriptBuilder.build(items: [withFile], settings: .standard)
        let reveal = script.phases.first { $0.kind == .revealL2 }
        if case let .file(courseId, path, fallback, tag) = reveal?.audio {
            #expect(courseId == "course_a")
            #expect(path == "audio/f.m4a")
            #expect(fallback == "Hello")
            #expect(tag == "en")
        } else {
            Issue.record("expected file audio")
        }
    }

    private func intro(of script: DriveScript) -> DriveAnnouncement? {
        guard let phase = script.phases.first, case let .announcement(ann) = phase.audio else {
            return nil
        }
        return ann
    }
}
