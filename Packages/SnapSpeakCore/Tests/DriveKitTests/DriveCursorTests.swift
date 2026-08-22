import DriveKit
import Foundation
import SRSKit
import Testing

@Suite("DriveCursor")
struct DriveCursorTests {
    @Test("C1 正常完走: itemCompleted が itemPassCount 回・順序どおり・finished(false)")
    func naturalCompletion() {
        let script = DriveScriptBuilder.build(
            items: [
                DriveFixtures.composition(id: "a"),
                DriveFixtures.composition(id: "b", origin: .new),
            ],
            settings: DriveFixtures.settings(timing: DriveFixtures.cappedTiming(2))
        )
        var cursor = DriveCursor(script: script)
        let outputs = cursor.playThrough()
        let completed = DriveCursor.completedRefs(in: outputs)
        #expect(completed.count == script.itemPassCount)
        #expect(completed.map(\.itemId) == ["a", "b"])
        #expect(completed.map(\.passIndex) == [0, 0])
        #expect(outputs.last == .finished(endedByUser: false))
        #expect(cursor.completedPassCount == script.itemPassCount)
    }

    @Test("C2 skipToNextItem は itemCompleted を出さない。完走完了数が 1 少ない")
    func skipDoesNotComplete() {
        let script = DriveScriptBuilder.build(
            items: [
                DriveFixtures.composition(id: "a"),
                DriveFixtures.composition(id: "b"),
            ],
            settings: DriveFixtures.settings(timing: DriveFixtures.cappedTiming(2))
        )
        var cursor = DriveCursor(script: script)
        var outputs = cursor.start()
        outputs.append(contentsOf: cursor.apply(.phaseFinished))
        let skip = cursor.apply(.skipToNextItem)
        #expect(skip.contains { if case .itemCompleted = $0 { return true }; return false } == false)
        outputs.append(contentsOf: skip)
        for _ in 0..<64 {
            let next = cursor.apply(.phaseFinished)
            outputs.append(contentsOf: next)
            if next.contains(where: { if case .finished = $0 { return true }; return false }) {
                break
            }
            if next.isEmpty { break }
        }
        let completed = DriveCursor.completedRefs(in: outputs)
        #expect(completed.map(\.itemId) == ["b"])
        #expect(completed.count == script.itemPassCount - 1)
        #expect(outputs.last == .finished(endedByUser: false))
    }

    @Test("C3 previousPressed: 途中→自 Item 頭 / 先頭→前 Item / 先頭 Item は留まる")
    func previousPressed() {
        let script = DriveScriptBuilder.build(
            items: [
                DriveFixtures.composition(id: "a"),
                DriveFixtures.composition(id: "b"),
            ],
            settings: .standard
        )
        let firstItemStart = script.phases.firstIndex { $0.item?.itemId == "a" } ?? -1
        let secondItemStart = script.phases.firstIndex { $0.item?.itemId == "b" } ?? -1

        var mid = DriveCursor(script: script)
        _ = mid.start()
        _ = mid.apply(.phaseFinished)
        _ = mid.apply(.phaseFinished)
        let replay = mid.apply(.previousPressed)
        #expect(replay == [.play(phaseIndex: firstItemStart)])

        var atHead = DriveCursor(script: script)
        _ = atHead.start()
        for _ in 0..<64 {
            let next = atHead.apply(.phaseFinished)
            if next.contains(where: { $0 == .play(phaseIndex: secondItemStart) }) { break }
            if next.isEmpty { break }
        }
        let back = atHead.apply(.previousPressed)
        #expect(back == [.play(phaseIndex: firstItemStart)])

        var first = DriveCursor(script: script)
        _ = first.start()
        _ = first.apply(.phaseFinished)
        let stay = first.apply(.previousPressed)
        #expect(stay == [.play(phaseIndex: firstItemStart)])
    }

    @Test("C4 pause 中の phaseFinished 無視 → resume で現在 Item の頭から")
    func pauseIgnoresFinishThenResumeRestartsItem() {
        let script = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "a")],
            settings: .standard
        )
        let itemStart = script.phases.firstIndex { $0.item != nil } ?? -1
        var cursor = DriveCursor(script: script)
        _ = cursor.start()
        _ = cursor.apply(.phaseFinished)
        _ = cursor.apply(.phaseFinished)
        #expect(cursor.apply(.pause).isEmpty)
        #expect(cursor.isPaused)
        #expect(cursor.apply(.phaseFinished).isEmpty)
        let resumed = cursor.apply(.resume)
        #expect(resumed == [.play(phaseIndex: itemStart)])
        #expect(cursor.isPaused == false)
    }

    @Test("C5 stop → finished(endedByUser: true)、以後のイベント無視")
    func stopIgnoresFurtherEvents() {
        let script = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "a")],
            settings: .standard
        )
        var cursor = DriveCursor(script: script)
        _ = cursor.start()
        #expect(cursor.apply(.stop) == [.finished(endedByUser: true)])
        #expect(cursor.apply(.phaseFinished).isEmpty)
        #expect(cursor.apply(.skipToNextItem).isEmpty)
        #expect(cursor.apply(.previousPressed).isEmpty)
        #expect(cursor.apply(.resume).isEmpty)
        #expect(cursor.apply(.stop).isEmpty)
        #expect(cursor.start().isEmpty)
    }

    @Test("C6 endless: 末尾で先頭 Item へ巻き戻り passIndex 加算・completedPassCount 累積")
    func endlessWrapsWithIncrementedPassIndex() {
        let script = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "a")],
            settings: DriveFixtures.settings(length: .endless)
        )
        #expect(script.loops)
        let firstItemStart = script.phases.firstIndex { $0.item != nil } ?? -1
        var cursor = DriveCursor(script: script)
        var outputs = cursor.start()
        var wraps = 0
        for _ in 0..<200 {
            let next = cursor.apply(.phaseFinished)
            outputs.append(contentsOf: next)
            if next.contains(where: { $0 == .play(phaseIndex: firstItemStart) }),
               DriveCursor.completedRefs(in: next).isEmpty == false {
                wraps += 1
            }
            if cursor.completedPassCount >= 2 { break }
        }
        let completed = DriveCursor.completedRefs(in: outputs)
        #expect(completed.map(\.passIndex) == [0, 1] || completed.map(\.passIndex).starts(with: [0, 1]))
        #expect(completed.filter { $0.itemId == "a" }.count >= 2)
        #expect(cursor.completedPassCount >= 2)
        #expect(wraps >= 1)
        #expect(outputs.contains { $0 == .finished(endedByUser: false) } == false)
    }

    @Test("C7 resume やり直しで同一 pass の itemCompleted が重複しない")
    func resumeDoesNotDuplicateCompletion() {
        let script = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "a")],
            settings: DriveFixtures.onePassStandard
        )
        var cursor = DriveCursor(script: script)
        var outputs = cursor.start()
        _ = cursor.apply(.phaseFinished)
        _ = cursor.apply(.phaseFinished)
        _ = cursor.apply(.pause)
        outputs.append(contentsOf: cursor.apply(.resume))
        for _ in 0..<64 {
            let next = cursor.apply(.phaseFinished)
            outputs.append(contentsOf: next)
            if next.isEmpty { break }
            if next.contains(where: { if case .finished = $0 { return true }; return false }) {
                break
            }
        }
        let completed = DriveCursor.completedRefs(in: outputs)
        #expect(completed.count == 1)
        #expect(completed.first?.itemId == "a")
        #expect(completed.first?.passIndex == 0)
    }

    @Test("アナウンス中の resume はそのアナウンスの頭から")
    func resumeDuringIntroReplaysIntro() {
        let script = DriveScriptBuilder.build(
            items: [DriveFixtures.composition(id: "a")],
            settings: .standard
        )
        var cursor = DriveCursor(script: script)
        #expect(cursor.start() == [.play(phaseIndex: 0)])
        _ = cursor.apply(.pause)
        #expect(cursor.apply(.resume) == [.play(phaseIndex: 0)])
    }
}
