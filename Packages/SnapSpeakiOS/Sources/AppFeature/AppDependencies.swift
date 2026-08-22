import Analytics
import AudioEngine
import Combine
import CompositionFeature
import ContentKit
import Foundation
import NotificationsKit
import Persistence
import ReviewFeature
import ShadowingFeature
import SpeechKit

@MainActor
public final class AppDependencies: ObservableObject {
    public let persistence: PersistenceActor
    public let audio: AudioEngineActor
    public let speech: SpeechClient
    public let courseStore: CourseStore
    public let downloads: DownloadManager
    public let manifest: ManifestService
    public let analytics: LocalAnalytics
    public let entitlement: EntitlementResolver
    public let seed: SeedInstaller
    public let settings: UserSettingsDTO
    public let shadowingUseCase: LiveShadowingUseCase
    public let compositionUseCase: LiveCompositionUseCase
    public let reminderScheduler: ReminderScheduler
    public let todayPlanService: TodayPlanService
    public let reminderDelegate: ReminderDelegate
    public let reminderRouter: ReminderRouter
    public let speechSynthesis: any SpeechSynthesizing
    public let driveFilePlayer: any PhaseFilePlaying
    public let driveSequencer: any DriveSequencing

    public init(
        persistence: PersistenceActor,
        audio: AudioEngineActor,
        speech: SpeechClient,
        courseStore: CourseStore,
        downloads: DownloadManager,
        manifest: ManifestService,
        analytics: LocalAnalytics,
        entitlement: EntitlementResolver,
        seed: SeedInstaller,
        settings: UserSettingsDTO,
        shadowingUseCase: LiveShadowingUseCase,
        compositionUseCase: LiveCompositionUseCase,
        reminderScheduler: ReminderScheduler,
        todayPlanService: TodayPlanService,
        reminderDelegate: ReminderDelegate,
        reminderRouter: ReminderRouter,
        speechSynthesis: any SpeechSynthesizing,
        driveFilePlayer: any PhaseFilePlaying,
        driveSequencer: any DriveSequencing
    ) {
        self.persistence = persistence
        self.audio = audio
        self.speech = speech
        self.courseStore = courseStore
        self.downloads = downloads
        self.manifest = manifest
        self.analytics = analytics
        self.entitlement = entitlement
        self.seed = seed
        self.settings = settings
        self.shadowingUseCase = shadowingUseCase
        self.compositionUseCase = compositionUseCase
        self.reminderScheduler = reminderScheduler
        self.todayPlanService = todayPlanService
        self.reminderDelegate = reminderDelegate
        self.reminderRouter = reminderRouter
        self.speechSynthesis = speechSynthesis
        self.driveFilePlayer = driveFilePlayer
        self.driveSequencer = driveSequencer
    }

    public static func live(resourceBundle: Bundle) throws -> AppDependencies {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let contentRoot = support.appendingPathComponent("Content", isDirectory: true)
        let recordings = support.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: contentRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)

        let container = try PersistenceActor.makeContainer(inMemory: false)
        let persistence = PersistenceActor(modelContainer: container)
        let analytics = LocalAnalytics()
        _ = InstallID.current()
        let audio = AudioEngineActor(analytics: analytics)
        let speech = SpeechClient()
        let seed = SeedInstaller(bundle: resourceBundle)
        let downloader = URLSessionDownloader()
        let courseStore = CourseStore(seed: seed, downloadsRoot: contentRoot)
        let downloads = DownloadManager(downloader: downloader, contentRoot: contentRoot)
        let manifest = ManifestService(downloader: downloader)
        let entitlement = EntitlementResolver()

        let shadowing = LiveShadowingUseCase(
            audio: audio,
            speech: speech,
            persistence: persistence,
            analytics: analytics,
            recordingsDirectory: recordings
        )
        let composition = LiveCompositionUseCase(
            audio: audio,
            speech: speech,
            persistence: persistence,
            analytics: analytics,
            recordingsDirectory: recordings
        )
        let reminderRouter = ReminderRouter()
        let reminderDelegate = ReminderDelegate(analytics: analytics, router: reminderRouter)
        let reminderScheduler = ReminderScheduler(center: LiveReminderCenter(), analytics: analytics)
        let todayPlanService = TodayPlanService(persistence: persistence, courseStore: courseStore)
        let speechSynthesis = SpeechSynthesisClient()
        let driveFilePlayer = SequenceFilePlayer()
        let driveSequencer = DriveSequencer(
            speech: speechSynthesis,
            filePlayer: driveFilePlayer
        )

        let settings: UserSettingsDTO = UserSettingsDTO.phase1Default
        return AppDependencies(
            persistence: persistence,
            audio: audio,
            speech: speech,
            courseStore: courseStore,
            downloads: downloads,
            manifest: manifest,
            analytics: analytics,
            entitlement: entitlement,
            seed: seed,
            settings: settings,
            shadowingUseCase: shadowing,
            compositionUseCase: composition,
            reminderScheduler: reminderScheduler,
            todayPlanService: todayPlanService,
            reminderDelegate: reminderDelegate,
            reminderRouter: reminderRouter,
            speechSynthesis: speechSynthesis,
            driveFilePlayer: driveFilePlayer,
            driveSequencer: driveSequencer
        )
    }

    public func loadSettings() async -> UserSettingsDTO {
        (try? await persistence.loadOrCreateSettings()) ?? settings
    }
}
