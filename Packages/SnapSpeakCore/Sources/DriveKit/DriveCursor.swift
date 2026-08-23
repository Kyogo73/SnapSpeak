import Foundation
import SRSKit

/// シーケンサの進行判断をすべて担う純状態機械。
public struct DriveCursor: Sendable, Equatable {
    public enum Event: Sendable, Equatable {
        case phaseFinished
        case skipToNextItem
        case previousPressed
        case pause
        case resume
        case stop
    }

    public enum Output: Sendable, Equatable {
        case play(phaseIndex: Int)
        case itemCompleted(DriveItemRef)
        case finished(endedByUser: Bool)
    }

    private struct ItemSpan: Sendable, Equatable {
        var ref: DriveItemRef
        var startIndex: Int
        var endIndex: Int
    }

    private let script: DriveScript
    private var phaseIndex = 0
    private var didStart = false
    private var isFinished = false
    public private(set) var isPaused = false
    public private(set) var completedPassCount = 0
    private var completedRefs: Set<DriveItemRef> = []
    /// endless で周回するたびに加算し、itemCompleted の passIndex に足す。
    private var loopPassOffset = 0
    /// 現在 Item で自然終了したフェーズ数（previous 判定用）。
    private var finishedPhasesInCurrentItem = 0

    public init(script: DriveScript) {
        self.script = script
    }

    public mutating func start() -> [Output] {
        guard !didStart, !isFinished else { return [] }
        didStart = true
        phaseIndex = 0
        finishedPhasesInCurrentItem = 0
        if script.phases.isEmpty {
            isFinished = true
            return [.finished(endedByUser: false)]
        }
        return [.play(phaseIndex: 0)]
    }

    public mutating func apply(_ event: Event) -> [Output] {
        guard didStart, !isFinished else { return [] }
        switch event {
        case .phaseFinished:
            return handlePhaseFinished()
        case .skipToNextItem:
            return handleSkip()
        case .previousPressed:
            return handlePrevious()
        case .pause:
            isPaused = true
            return []
        case .resume:
            return handleResume()
        case .stop:
            isFinished = true
            isPaused = false
            return [.finished(endedByUser: true)]
        }
    }

    private mutating func handlePhaseFinished() -> [Output] {
        guard !isPaused, script.phases.indices.contains(phaseIndex) else { return [] }
        var outputs: [Output] = []
        if let span = itemSpan(containing: phaseIndex) {
            finishedPhasesInCurrentItem += 1
            if phaseIndex == span.endIndex {
                outputs.append(contentsOf: emitCompletion(for: span.ref))
            }
        }
        let next = phaseIndex + 1
        if next < script.phases.count {
            phaseIndex = next
            if itemSpan(containing: phaseIndex)?.ref != itemSpan(containing: next - 1)?.ref {
                finishedPhasesInCurrentItem = 0
            }
            outputs.append(.play(phaseIndex: phaseIndex))
            return outputs
        }
        if script.loops {
            outputs.append(contentsOf: wrapToFirstItem())
            return outputs
        }
        isFinished = true
        outputs.append(.finished(endedByUser: false))
        return outputs
    }

    private mutating func handleSkip() -> [Output] {
        guard !isFinished else { return [] }
        isPaused = false
        finishedPhasesInCurrentItem = 0
        if let nextStart = nextItemStart(after: phaseIndex) {
            phaseIndex = nextStart
            return [.play(phaseIndex: phaseIndex)]
        }
        if script.loops {
            return wrapToFirstItem()
        }
        isFinished = true
        return [.finished(endedByUser: false)]
    }

    private mutating func handlePrevious() -> [Output] {
        guard !isFinished else { return [] }
        isPaused = false
        if currentPhaseIsAnnouncement {
            return handlePreviousOnAnnouncement()
        }
        guard let span = itemSpan(containing: phaseIndex) else {
            return [.play(phaseIndex: phaseIndex)]
        }
        if finishedPhasesInCurrentItem == 0, let previous = previousItemStart(before: span.startIndex) {
            phaseIndex = previous
            finishedPhasesInCurrentItem = 0
            return [.play(phaseIndex: phaseIndex)]
        }
        phaseIndex = span.startIndex
        finishedPhasesInCurrentItem = 0
        return [.play(phaseIndex: phaseIndex)]
    }

    private mutating func handlePreviousOnAnnouncement() -> [Output] {
        let kind = script.phases[phaseIndex].kind
        switch kind {
        case .sessionIntro:
            return [.play(phaseIndex: phaseIndex)]
        case .sectionAnnounce, .sessionOutro:
            if let previous = previousItemStart(before: phaseIndex) {
                phaseIndex = previous
                finishedPhasesInCurrentItem = 0
                return [.play(phaseIndex: phaseIndex)]
            }
            return [.play(phaseIndex: phaseIndex)]
        default:
            return [.play(phaseIndex: phaseIndex)]
        }
    }

    private mutating func handleResume() -> [Output] {
        guard isPaused else { return [] }
        isPaused = false
        if currentPhaseIsAnnouncement {
            return [.play(phaseIndex: phaseIndex)]
        }
        if let span = itemSpan(containing: phaseIndex) {
            phaseIndex = span.startIndex
            finishedPhasesInCurrentItem = 0
        }
        return [.play(phaseIndex: phaseIndex)]
    }

    private mutating func wrapToFirstItem() -> [Output] {
        guard let first = firstItemStart else {
            isFinished = true
            return [.finished(endedByUser: false)]
        }
        loopPassOffset += 1
        phaseIndex = first
        finishedPhasesInCurrentItem = 0
        return [.play(phaseIndex: phaseIndex)]
    }

    private mutating func emitCompletion(for ref: DriveItemRef) -> [Output] {
        let adjusted = DriveItemRef(
            courseId: ref.courseId,
            itemId: ref.itemId,
            skill: ref.skill,
            passIndex: ref.passIndex + loopPassOffset
        )
        guard !completedRefs.contains(adjusted) else { return [] }
        completedRefs.insert(adjusted)
        completedPassCount += 1
        return [.itemCompleted(adjusted)]
    }

    private var currentPhaseIsAnnouncement: Bool {
        guard script.phases.indices.contains(phaseIndex) else { return false }
        return script.phases[phaseIndex].item == nil
    }

    private var firstItemStart: Int? {
        script.phases.firstIndex { $0.item != nil }
    }

    private func itemSpan(containing index: Int) -> ItemSpan? {
        itemSpans.first { index >= $0.startIndex && index <= $0.endIndex }
    }

    private func nextItemStart(after index: Int) -> Int? {
        itemSpans.first { $0.startIndex > index }?.startIndex
    }

    private func previousItemStart(before index: Int) -> Int? {
        itemSpans.last { $0.startIndex < index }?.startIndex
    }

    private var itemSpans: [ItemSpan] {
        var spans: [ItemSpan] = []
        var index = 0
        let phases = script.phases
        while index < phases.count {
            guard let ref = phases[index].item else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < phases.count, phases[end + 1].item == ref {
                end += 1
            }
            spans.append(ItemSpan(ref: ref, startIndex: index, endIndex: end))
            index = end + 1
        }
        return spans
    }
}
