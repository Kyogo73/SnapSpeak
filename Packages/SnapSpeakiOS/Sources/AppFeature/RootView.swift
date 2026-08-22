import ContentCore
import ContentKit
import HabitKit
import OnboardingFeature
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
    @State private var driveSession: DriveSessionLaunch?

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
                Task { await todayViewModel?.refresh() }
            }
        }
        .onReceive(dependencies.reminderRouter.$homeRevealToken) { token in
            guard token > 0 else { return }
            selectedTab = .home
            homePath.removeAll()
            catalogPath.removeAll()
            settingsPath.removeAll()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .fullScreenCover(item: $driveSession) { launch in
            DriveSessionContainer(
                launch: launch,
                courses: courses,
                dependencies: dependencies,
                today: todayViewModel,
                onClose: {
                    driveSession = nil
                    Task { await todayViewModel?.refresh() }
                },
                onOpenLesson: { coordinate in
                    driveSession = nil
                    homePath.append(.lesson(coordinate))
                    Task { await todayViewModel?.refresh() }
                }
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingContainerView(
                persistence: dependencies.persistence,
                scheduler: dependencies.reminderScheduler,
                analytics: dependencies.analytics,
                onFinished: { startFirstLesson in
                    showOnboarding = false
                    Task { await todayViewModel?.refresh() }
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
                onContinueLearning: { selectedTab = .catalog },
                onOpenDrive: { Task { await presentDrive(immediate: false) } },
                onQuickStartDrive: { Task { await presentDrive(immediate: true) } }
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
                    },
                    onItemCompleted: {
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
        StandaloneLessonHost(
            coordinate: coordinate,
            dependencies: dependencies,
            today: todayViewModel
        )
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

    private func presentDrive(immediate: Bool) async {
        guard !courses.isEmpty else { return }
        await dependencies.audio.stop()
        let prepared: (plan: SessionPlan, loadFailed: Bool)
        if let todayViewModel {
            prepared = await todayViewModel.prepareDrivePlan()
        } else {
            prepared = (SessionPlan(reviews: [], deferredDueCount: 0, newLesson: nil), true)
        }
        let settings = await dependencies.loadSettings()
        driveSession = DriveSessionLaunch(
            plan: prepared.plan,
            settings: settings,
            startImmediately: immediate,
            loadFailed: prepared.loadFailed
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
