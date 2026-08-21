import AppFeature
import SwiftUI

@main
struct SnapSpeakApp: App {
    @StateObject private var dependencies: AppDependencies

    init() {
        do {
            let live = try AppBootstrap.makeDependencies()
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
