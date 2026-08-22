import Analytics
import AudioEngine
import ContentKit
import DriveKit
import Foundation
import HabitKit
import Persistence
import SRSKit

@MainActor
public final class DriveSessionViewModel: ObservableObject {
    public enum Phase: Equatable {
        case idle
        case starting
        case running(phaseKind: DrivePhaseKind, itemIndex: Int, paused: Bool)
        case finished(note: DriveNote)
    }

    public struct DriveNote: Sendable, Equatable {
        public var rows: [DriveNoteRow]
        public var completedCount: Int
        public var usedTTSFallback: Bool
        public var missingCount: Int
        public var endReason: String
    }

    public struct DriveNoteRow: Sendable, Equatable, Identifiable {
        public var id: String { "\(courseId)|\(itemId)" }
        public var courseId: String
        public var lessonId: String
        public var itemId: String
        public var skill: Skill
        public var l1Text: String?
        public var l2Text: String
        public var passCount: Int
        public var audioRelativePath: String?
        public var l2LanguageTag: String
        public var courseTitle: String
    }

    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var completedCount = 0
    @Published public private(set) var plannedCount = 0
    @Published public private(set) var loadFailed = false
    @Published public private(set) var isRepeatFill = false
    @Published public private(set) var dueCount = 0
    @Published public private(set) var newCount = 0
    @Published public private(set) var currentCourseTitle = ""

    private let sequencer: any DriveSequencing
    private let recorder: DriveAttemptRecorder
    private let analytics: any AnalyticsClient
    private var settings = DriveScriptSettings.standard
    private var resolution = DrivePlanResolver.Resolution(items: [], lookups: [:], skipped: 0)
    private var itemsByKey: [String: DriveItem] = [:]
    private var noteRows: [DriveNoteRow] = []
    private var sessionUsedTTS = false
    private var skippedMissing = 0
    private var listenTask: Task<Void, Never>?
    private var startedAt = Date()
    private var itemOrder: [String] = []
    public var onOpenLesson: ((String, String, String, Skill) -> Void)?

    public init(
        sequencer: any DriveSequencing,
        recorder: DriveAttemptRecorder,
        analytics: any AnalyticsClient
    ) {
        self.sequencer = sequencer
        self.recorder = recorder
        self.analytics = analytics
    }

    public func prepare(plan: SessionPlan, courses: [StoredCourse], settings: DriveScriptSettings) {
        self.settings = settings
        var resolved = DrivePlanResolver.resolve(plan: plan, courses: courses)
        isRepeatFill = resolved.items.isEmpty
        if resolved.items.isEmpty {
            resolved = DrivePlanResolver.repeatFillItems(courses: courses)
        }
        resolution = resolved
        dueCount = resolved.items.filter { $0.origin == .due }.count
        newCount = resolved.items.filter { $0.origin == .new }.count
        itemsByKey = Dictionary(
            uniqueKeysWithValues: resolved.items.map {
                (DrivePlanResolver.itemKey(courseId: $0.courseId, itemId: $0.itemId), $0)
            }
        )
        loadFailed = false
        phase = .idle
    }

    public func markLoadFailed() {
        loadFailed = true
        phase = .idle
    }

    public func applyLength(_ length: DriveScriptSettings.SessionLength) {
        settings.sessionLength = length
    }

    public func start(courses: [StoredCourse]) async {
        phase = .starting
        startedAt = Date()
        noteRows = []
        completedCount = 0
        sessionUsedTTS = false
        skippedMissing = resolution.skipped
        itemOrder = []
        let script = DriveScriptBuilder.build(items: resolution.items, settings: settings)
        plannedCount = script.itemPassCount
        analytics.track(
            .driveSessionStarted(
                dueCount: dueCount,
                newCount: newCount,
                lengthCode: settings.lengthCode
            )
        )
        listenTask?.cancel()
        listenTask = Task { await self.listen() }
        await sequencer.start(
            script: script,
            announcementTexts: DriveAnnouncementText.texts(for: script),
            outroText: { DriveAnnouncementText.outro(completedCount: $0) },
            assets: CourseDirectoryResolver(courses: courses)
        )
        if case .starting = phase {
            phase = .running(phaseKind: .sessionIntro, itemIndex: 0, paused: false)
        }
    }

    public func pause() async { await sequencer.pause() }
    public func resume() async { await sequencer.resume() }
    public func stop() async { await sequencer.stop() }

    public func replay(row: DriveNoteRow, speech: any SpeechSynthesizing, files: any PhaseFilePlaying) async {
        if let path = row.audioRelativePath,
           let url = resolution.lookups[DrivePlanResolver.itemKey(courseId: row.courseId, itemId: row.itemId)]?
            .directory.appendingPathComponent(path) {
            do {
                try await files.play(url: url)
                return
            } catch {
                // TTS fallback
            }
        }
        try? await speech.speak(text: row.l2Text, languageTag: row.l2LanguageTag)
    }

    public func openLesson(_ row: DriveNoteRow) {
        onOpenLesson?(row.courseId, row.lessonId, row.itemId, row.skill)
    }

    public func noteOpened() {
        if case let .finished(note) = phase {
            analytics.track(.driveNoteOpened(completedCount: note.completedCount))
        }
    }

    private func listen() async {
        for await event in sequencer.events() {
            handle(event)
        }
    }

    private func handle(_ event: DriveSequencerEvent) {
        switch event {
        case let .phaseChanged(kind, itemRef):
            let index = itemIndex(for: itemRef)
            let paused = if case let .running(_, _, paused) = phase { paused } else { false }
            if let itemRef {
                let key = DrivePlanResolver.itemKey(courseId: itemRef.courseId, itemId: itemRef.itemId)
                currentCourseTitle = resolution.lookups[key]?.courseTitle ?? ""
            }
            phase = .running(phaseKind: kind, itemIndex: index, paused: paused)
        case let .itemCompleted(ref, usedTTS, elapsed):
            sessionUsedTTS = sessionUsedTTS || usedTTS
            completedCount += 1
            let key = DrivePlanResolver.itemKey(courseId: ref.courseId, itemId: ref.itemId)
            if let item = itemsByKey[key], let lookup = resolution.lookups[key] {
                appendNote(item: item, lookup: lookup)
            }
            Task { await self.persist(ref: ref, usedTTS: usedTTS, elapsed: elapsed) }
        case .itemSkipped:
            skippedMissing += 1
        case .paused:
            if case let .running(kind, index, _) = phase {
                phase = .running(phaseKind: kind, itemIndex: index, paused: true)
            }
        case .resumed:
            if case let .running(kind, index, _) = phase {
                phase = .running(phaseKind: kind, itemIndex: index, paused: false)
            }
        case let .finished(endedByUser, count):
            completedCount = count
            finish(endedByUser: endedByUser)
        }
    }

    private func persist(ref: DriveItemRef, usedTTS: Bool, elapsed: Int) async {
        let key = DrivePlanResolver.itemKey(courseId: ref.courseId, itemId: ref.itemId)
        guard let item = itemsByKey[key], let lookup = resolution.lookups[key] else { return }
        _ = try? await recorder.record(
            item: item,
            lookup: lookup,
            passIndex: ref.passIndex,
            usedTTSFallback: usedTTS,
            elapsedMs: elapsed,
            settings: settings
        )
    }

    private func appendNote(item: DriveItem, lookup: DrivePlanResolver.Lookup) {
        let key = DrivePlanResolver.itemKey(courseId: item.courseId, itemId: item.itemId)
        if let index = noteRows.firstIndex(where: { $0.id == key }) {
            noteRows[index].passCount += 1
            return
        }
        noteRows.append(
            DriveNoteRow(
                courseId: item.courseId,
                lessonId: lookup.lessonId,
                itemId: item.itemId,
                skill: item.skill,
                l1Text: item.l1Text,
                l2Text: item.l2Text,
                passCount: 1,
                audioRelativePath: item.audioRelativePath,
                l2LanguageTag: item.l2LanguageTag,
                courseTitle: lookup.courseTitle
            )
        )
    }

    private func finish(endedByUser: Bool) {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        let reason = endedByUser ? "stopped" : "finished"
        analytics.track(
            .driveSessionCompleted(
                completedCount: completedCount,
                durationBand: Quantization.durationBand(ms: durationMs),
                endReason: reason,
                usedTTSFallback: sessionUsedTTS
            )
        )
        phase = .finished(
            note: DriveNote(
                rows: noteRows,
                completedCount: completedCount,
                usedTTSFallback: sessionUsedTTS,
                missingCount: skippedMissing,
                endReason: reason
            )
        )
    }

    private func itemIndex(for ref: DriveItemRef?) -> Int {
        guard let ref else { return 0 }
        let key = DrivePlanResolver.itemKey(courseId: ref.courseId, itemId: ref.itemId)
        if let existing = itemOrder.firstIndex(of: key) { return existing }
        itemOrder.append(key)
        return itemOrder.count - 1
    }
}
