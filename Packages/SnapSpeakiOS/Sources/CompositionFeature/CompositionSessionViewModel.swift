import CompositionKit
import ContentCore
import ContentKit
import Foundation
import SwiftUI

@MainActor
public final class CompositionSessionViewModel: ObservableObject {
    public enum Phase {
        case loading
        case prompt
        case recording
        case scoring
        case result
        case failed(String)
    }

    @Published public private(set) var phase: Phase = .loading
    @Published public var typedText: String = ""
    @Published public private(set) var l1Text: String = ""
    @Published public private(set) var outcome: CompositionOutcome?
    @Published public private(set) var microphoneDenied = false
    @Published public var usedHint = false

    public let courseId: String
    public let lessonId: String
    public let itemId: String

    private let useCase: any CompositionUseCase
    private let courseStore: CourseStore
    private var stored: StoredCourse?
    private var item: ItemV1?
    private var promptShownAt = Date()
    private var recordingURL: URL?

    public init(
        courseId: String,
        lessonId: String,
        itemId: String,
        useCase: any CompositionUseCase,
        courseStore: CourseStore
    ) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.useCase = useCase
        self.courseStore = courseStore
    }

    public func load() async {
        phase = .loading
        let courses = await courseStore.allCourses()
        guard let stored = courses.first(where: { $0.course.id == courseId }) else {
            phase = .failed("missing-course")
            return
        }
        let match = stored.course.units
            .flatMap(\.lessons)
            .first(where: { $0.id == lessonId })?
            .items
            .first(where: { $0.id == itemId })
        guard let match else {
            phase = .failed("missing-item")
            return
        }
        self.stored = stored
        self.item = match
        l1Text = match.sentencePair?.l1 ?? ""
        promptShownAt = Date()
        phase = .prompt
    }

    public func submitTyped() async {
        guard let item, let stored else { return }
        phase = .scoring
        let clock = ResponseClock(t0: promptShownAt, tEnd: Date())
        do {
            outcome = try await useCase.gradeTyped(
                item: item,
                stored: stored,
                lessonId: lessonId,
                input: typedText,
                latencyMs: clock.latencyMs,
                usedHint: usedHint
            )
            phase = .result
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    public func startSpeaking() async {
        guard let item else { return }
        do {
            recordingURL = try await useCase.startRecording(item: item)
            microphoneDenied = false
            phase = .recording
        } catch CompositionUseCaseError.microphoneDenied {
            microphoneDenied = true
            phase = .prompt
        } catch {
            phase = .prompt
        }
    }

    public func finishSpeaking() async {
        guard let item, let stored, let recordingURL else { return }
        phase = .scoring
        let clock = ResponseClock(t0: promptShownAt, tEnd: Date())
        do {
            outcome = try await useCase.finishRecording(
                item: item,
                stored: stored,
                lessonId: lessonId,
                recordingURL: recordingURL,
                latencyMs: clock.latencyMs,
                usedHint: usedHint
            )
            phase = .result
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    public func revealHint() {
        usedHint = true
    }
}
