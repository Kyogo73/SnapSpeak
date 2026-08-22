import AppFeature
import SwiftUI
import UserNotifications

@main
struct SnapSpeakApp: App {
    @StateObject private var dependencies: AppDependencies

    init() {
        do {
            let live = try AppBootstrap.makeDependencies()
            UNUserNotificationCenter.current().delegate = live.reminderDelegate
            _dependencies = StateObject(wrappedValue: live)
        } catch {
            preconditionFailure("Failed to bootstrap SnapSpeak: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
        }
    }
}
