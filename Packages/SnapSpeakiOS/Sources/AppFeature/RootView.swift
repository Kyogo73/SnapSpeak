import CompositionFeature
import ContentCore
import ContentKit
import HabitKit
import OnboardingFeature
import ReviewFeature
import ShadowingFeature
import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var todayViewModelHolder = TodayViewModelBox()
    @State private var courses: [StoredCourse] = []
    @State private var homePath: [HomeDestination] = []
    @State private var catalogPath: [LessonCoordinate] = []
    @State private var settingsPath: [SettingsDestination] = []
    @State private var selectedTab: AppTab = .home
    @State private var showOnboarding = false

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                homeRoot
                    .navigationDestination(for: HomeDestination.self, destination: homeDestination)
            }
            .tabItem { Label("tab.home", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $catalogPath) {
                CatalogView(path: $catalogPath, courses: courses)
                    .navigationDestination(for: LessonCoordinate.self, destination: lessonDestination)
            }
            .tabItem { Label("tab.catalog", systemImage: "books.vertical") }
            .tag(AppTab.catalog)

            NavigationStack(path: $settingsPath) {
                SettingsView(path: $settingsPath, today: todayViewModel)
                    .navigationDestination(for: SettingsDestination.self) { destination in
                        switch destination {
                        case .privacy:
                            PrivacyView()
                        case .downloads:
                            DownloadsView(courses: courses)
                        }
                    }
            }
            .tabItem { Label("tab.settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .task { await bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await todayViewModel.refresh() }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView(
                viewModel: OnboardingViewModel(
                    persistence: dependencies.persistence,
                    scheduler: dependencies.reminderScheduler,
                    analytics: dependencies.analytics
                ),
                onFinished: { startFirstLesson in
                    showOnboarding = false
                    Task { await todayViewModel.refresh() }
                    if startFirstLesson, let lesson = firstLesson {
                        homePath.append(.lesson(lesson))
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var homeRoot: some View {
        if let todayViewModel {
            HomeView(
                path: $homePath,
                courses: courses,
                today: todayViewModel,
                onContinueLearning: { selectedTab = .catalog }
            )
        } else {
            ProgressView()
        }
    }

    private var todayViewModel: TodayViewModel? {
        todayViewModelHolder.viewModel
    }

    @ViewBuilder
    private func homeDestination(_ destination: HomeDestination) -> some View {
        switch destination {
        case let .lesson(coordinate):
            lessonDestination(coordinate)
        case .review:
            if let todayViewModel, let snapshot = todayViewModel.snapshot {
                ReviewSessionContainer(
                    snapshot: snapshot,
                    dependencies: dependencies,
                    onClose: {
                        homePath.removeAll { $0 == .review }
                        Task { await todayViewModel.refresh() }
                    },
                    onContinueLearning: {
                        homePath.removeAll { $0 == .review }
                        selectedTab = .catalog
                        Task { await todayViewModel.refresh() }
                    }
                )
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func lessonDestination(_ coordinate: LessonCoordinate) -> some View {
        switch coordinate.mode {
        case .shadowing:
            ShadowingLessonView(
                viewModel: ShadowingLessonViewModel(
                    courseId: coordinate.courseId,
                    lessonId: coordinate.lessonId,
                    itemId: coordinate.itemId,
                    useCase: dependencies.shadowingUseCase,
                    courseStore: dependencies.courseStore,
                    captionsEnabled: dependencies.settings.captionsEnabled,
                    defaultRate: dependencies.settings.defaultRate
                )
            )
        case .composition:
            CompositionCardView(
                viewModel: CompositionSessionViewModel(
                    courseId: coordinate.courseId,
                    lessonId: coordinate.lessonId,
                    itemId: coordinate.itemId,
                    useCase: dependencies.compositionUseCase,
                    courseStore: dependencies.courseStore
                )
            )
        }
    }

    private func bootstrap() async {
        if todayViewModelHolder.viewModel == nil {
            todayViewModelHolder.viewModel = TodayViewModel(
                persistence: dependencies.persistence,
                todayPlanService: dependencies.todayPlanService,
                scheduler: dependencies.reminderScheduler,
                analytics: dependencies.analytics
            )
        }
        courses = await dependencies.courseStore.allCourses()
        let settings = (try? await dependencies.persistence.loadOrCreateSettings()) ?? dependencies.settings
        showOnboarding = settings.onboardingCompletedAt == nil
        await todayViewModel?.refresh()
    }

    private var firstLesson: LessonCoordinate? {
        guard let stored = courses.first,
              let lesson = stored.course.units.first?.lessons.first,
              let item = lesson.items.first
        else { return nil }
        return LessonCoordinate(
            courseId: stored.course.id,
            lessonId: lesson.id,
            itemId: item.id,
            mode: lesson.mode
        )
    }

    private func handleDeepLink(_ url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard url.host == "lesson" || parts.first == "lesson" else { return }
        let ids = url.host == "lesson" ? parts : Array(parts.dropFirst())
        guard ids.count >= 3 else { return }
        let coordinate = LessonCoordinate(
            courseId: ids[0],
            lessonId: ids[1],
            itemId: ids[2],
            mode: .shadowing
        )
        homePath.append(.lesson(coordinate))
    }
}

/// Holds `TodayViewModel` so `RootView` can construct it after `AppDependencies` is available.
@MainActor
private final class TodayViewModelBox: ObservableObject {
    @Published var viewModel: TodayViewModel?
}

private struct ReviewSessionContainer: View {
    @StateObject private var session: ReviewSessionViewModel
    let snapshot: TodaySnapshot
    let dependencies: AppDependencies
    let onClose: () -> Void
    let onContinueLearning: () -> Void

    init(
        snapshot: TodaySnapshot,
        dependencies: AppDependencies,
        onClose: @escaping () -> Void,
        onContinueLearning: @escaping () -> Void
    ) {
        _session = StateObject(
            wrappedValue: ReviewSessionViewModel(
                plan: snapshot.plan,
                courseStore: dependencies.courseStore,
                analytics: dependencies.analytics
            )
        )
        self.snapshot = snapshot
        self.dependencies = dependencies
        self.onClose = onClose
        self.onContinueLearning = onContinueLearning
    }

    var body: some View {
        let streakTo = snapshot.streak.studiedToday
            ? snapshot.streak.currentStreakDays
            : snapshot.streak.currentStreakDays + (snapshot.plan.isEmpty ? 0 : 1)
        ReviewSessionView(
            viewModel: session,
            itemContent: { entry, onFinished in
                itemView(for: entry, onFinished: onFinished)
            },
            onClose: onClose,
            onContinueLearning: onContinueLearning,
            didMeetGoal: snapshot.goal.isMet,
            streakFrom: snapshot.streak.currentStreakDays,
            streakTo: streakTo
        )
    }

    @ViewBuilder
    private func itemView(for entry: ReviewEntry, onFinished: @escaping () -> Void) -> some View {
        switch entry.mode {
        case .shadowing:
            ShadowingLessonView(
                viewModel: ShadowingLessonViewModel(
                    courseId: entry.courseId,
                    lessonId: entry.lessonId,
                    itemId: entry.itemId,
                    useCase: dependencies.shadowingUseCase,
                    courseStore: dependencies.courseStore,
                    captionsEnabled: dependencies.settings.captionsEnabled,
                    defaultRate: dependencies.settings.defaultRate
                ),
                onCompleted: onFinished
            )
        case .composition:
            CompositionCardView(
                viewModel: CompositionSessionViewModel(
                    courseId: entry.courseId,
                    lessonId: entry.lessonId,
                    itemId: entry.itemId,
                    useCase: dependencies.compositionUseCase,
                    courseStore: dependencies.courseStore
                ),
                onCompleted: onFinished
            )
        }
    }
}
