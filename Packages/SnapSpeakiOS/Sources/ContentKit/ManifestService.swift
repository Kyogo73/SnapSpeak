import ContentCore
import Foundation
import LanguageKit

public actor ManifestService {
    private let downloader: any HTTPDownloading

    public init(downloader: any HTTPDownloading) {
        self.downloader = downloader
    }

    public func fetch(from url: URL) async throws -> Manifest {
        let data = try await downloader.data(from: url)
        return try Manifest.decode(from: data)
    }

    public func selectedRelease(
        for course: ManifestCourse,
        appVersion: AppVersion
    ) -> CourseRelease? {
        ReleaseSelector.select(
            course: course,
            appVersion: appVersion,
            knownSchemas: KnownContentSchemaVersions
        )
    }

    public static func appVersion(from bundle: Bundle = .main) -> AppVersion {
        let raw = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return (try? AppVersion(raw)) ?? AppVersion(major: 1, minor: 0, patch: 0)
    }
}
