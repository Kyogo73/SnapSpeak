import AudioEngine
import ContentCore
import ContentKit
import Foundation
import LanguageKit
import ScoringKit
import SwiftUI

@MainActor
public final class ShadowingLessonViewModel: ObservableObject {
    public enum FailureKind: Sendable, Equatable {
        case load
        case playback
        case scoring
    }

    public enum Phase: Sendable, Equatable {
        case loading
        case ready
        case playing
        case scoring
        case scored
        case completed
        case degradedNoASR
        case microphoneDenied
        case failed(FailureKind)
    }

    @Published public private(set) var phase: Phase = .loading
    @Published public var captionsEnabled: Bool
    @Published public var rate: Float
    @Published public private(set) var score: ShadowingScore?
    @Published public private(set) var passageText: String = ""
    @Published public private(set) var captions: [CaptionSegment] = []
    @Published public private(set) var decision: RouteDecision?

    public let courseId: String
    public let lessonId: String
    public let itemId: String

    private let useCase: any ShadowingUseCase
    private let courseStore: CourseStore
    private var stored: StoredCourse?
    private var item: ItemV1?
    private var asrReady = false

    public init(
        courseId: String,
        lessonId: String,
        itemId: String,
        useCase: any ShadowingUseCase,
        courseStore: CourseStore,
        captionsEnabled: Bool,
        defaultRate: Float
    ) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.useCase = useCase
        self.courseStore = courseStore
        self.captionsEnabled = captionsEnabled
        self.rate = min(max(defaultRate, 0.5), 1.5)
    }

    public func load() async {
        phase = .loading
        let courses = await courseStore.allCourses()
        guard let stored = courses.first(where: { $0.course.id == courseId }) else {
            phase = .failed(.load)
            return
        }
        let match = stored.course.units
            .flatMap(\.lessons)
            .first(where: { $0.id == lessonId })?
            .items
            .first(where: { $0.id == itemId })
        guard let match else {
            phase = .failed(.load)
            return
        }
        self.stored = stored
        self.item = match
        passageText = match.passage?.text ?? ""
        captions = match.passage?.captionSegments ?? []
        let preparation = await useCase.prepare(
            targetLanguage: stored.course.languagePair.targetLanguage
        )
        asrReady = preparation.asrReady
        decision = preparation.decision
        if preparation.asrReady {
            phase = .ready
        } else {
            phase = .degradedNoASR
        }
    }

    public func start() async {
        guard let item, let stored else { return }
        do {
            try await useCase.startPlayback(
                item: item,
                stored: stored,
                rate: rate
            )
            phase = .playing
        } catch ShadowingUseCaseError.microphoneDenied {
            phase = .microphoneDenied
        } catch {
            phase = .failed(.playback)
        }
    }

    /// マイク拒否時のお手本再生（録音しない）。
    public func replayPreview() async {
        guard let item, let stored else { return }
        do {
            try await useCase.startPreviewPlayback(item: item, stored: stored, rate: rate)
            phase = .microphoneDenied
        } catch ShadowingUseCaseError.microphoneDenied {
            phase = .microphoneDenied
        } catch {
            phase = .failed(.playback)
        }
    }

    public func stopAndScore() async {
        guard let item, let stored else { return }
        phase = .scoring
        do {
            let liveASR = asrReady && !(decision?.isDegraded ?? false)
            let completion = try await useCase.stopAndScore(
                item: item,
                stored: stored,
                lessonId: lessonId,
                rate: rate,
                asrReady: liveASR
            )
            score = completion.score
            if completion.persisted {
                phase = completion.score == nil ? .completed : .scored
            } else if completion.score == nil {
                phase = .degradedNoASR
            } else {
                phase = .scored
            }
        } catch {
            phase = .failed(.scoring)
        }
    }

    public func retryAfterScoringFailure() {
        score = nil
        phase = asrReady ? .ready : .degradedNoASR
    }
}
