import AppFeature
import Foundation

enum AppBootstrap {
    @MainActor
    static func makeDependencies(bundle: Bundle = .main) throws -> AppDependencies {
        try AppDependencies.live(resourceBundle: bundle)
    }
}
