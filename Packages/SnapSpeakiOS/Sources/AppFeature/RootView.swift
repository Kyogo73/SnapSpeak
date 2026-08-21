import CompositionFeature
import ContentCore
import ContentKit
import ShadowingFeature
import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var courses: [StoredCourse] = []
    @State private var homePath: [LessonCoordinate] = []
    @State private var catalogPath: [LessonCoordinate] = []
    @State private var settingsPath: [SettingsDestination] = []

    public init() {}

    public var body: some View {
        TabView {
            NavigationStack(path: $homePath) {
                HomeView(path: $homePath, courses: courses)
                    .navigationDestination(for: LessonCoordinate.self, destination: lessonDestination)
            }
            .tabItem { Label("tab.home", systemImage: "house") }

            NavigationStack(path: $catalogPath) {
                CatalogView(path: $catalogPath, courses: courses)
                    .navigationDestination(for: LessonCoordinate.self, destination: lessonDestination)
            }
            .tabItem { Label("tab.catalog", systemImage: "books.vertical") }

            NavigationStack(path: $settingsPath) {
                SettingsView(path: $settingsPath)
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
        }
        .task {
            courses = await dependencies.courseStore.allCourses()
            _ = try? await dependencies.persistence.loadOrCreateSettings()
        }
        .onOpenURL { url in
            handleDeepLink(url)
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
        homePath.append(coordinate)
    }
}
