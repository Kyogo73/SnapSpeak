import Foundation
import LanguageKit

public enum ReleaseSelector {
    /// `minAppVersion ≤ app < maxAppVersion` and schema known → highest revision. None → nil (keep local).
    public static func select(
        course: ManifestCourse,
        appVersion: AppVersion,
        knownSchemas: [Int] = KnownContentSchemaVersions
    ) -> CourseRelease? {
        let eligible = course.releases.filter { release in
            guard knownSchemas.contains(release.schemaVersion) else { return false }
            guard release.minAppVersion <= appVersion else { return false }
            if let max = release.maxAppVersion, appVersion >= max { return false }
            return true
        }
        return eligible.max { lhs, rhs in
            if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
            return lhs.releaseId < rhs.releaseId
        }
    }
}
