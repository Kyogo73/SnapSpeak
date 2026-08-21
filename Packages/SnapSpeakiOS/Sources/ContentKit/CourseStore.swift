import ContentCore
import Foundation

public enum StoredCourseOrigin: String, Sendable, Equatable {
    case seed
    case downloaded
}

/// Sidecar written next to `index.json` so `inheritSRS` survives download without a SwiftData schema change.
public struct ReleaseMeta: Codable, Sendable, Equatable {
    public static let fileName = "release-meta.json"

    public var inheritSRS: Bool
    public var releaseId: String
    public var revision: Int

    public init(inheritSRS: Bool, releaseId: String, revision: Int) {
        self.inheritSRS = inheritSRS
        self.releaseId = releaseId
        self.revision = revision
    }
}

public struct StoredCourse: Sendable, Equatable {
    public var course: Course
    public var origin: StoredCourseOrigin
    public var directory: URL
    public var revision: Int
    public var releaseId: String?
    /// From the selected `CourseRelease`. Seed/legacy downloads default to `true`.
    public var inheritSRS: Bool

    public init(
        course: Course,
        origin: StoredCourseOrigin,
        directory: URL,
        revision: Int,
        releaseId: String?,
        inheritSRS: Bool = true
    ) {
        self.course = course
        self.origin = origin
        self.directory = directory
        self.revision = revision
        self.releaseId = releaseId
        self.inheritSRS = inheritSRS
    }
}

/// Enumerates seed + downloaded courses. Unknown schema versions are skipped (keep local).
public actor CourseStore {
    private let seed: SeedInstaller
    private let downloadsRoot: URL

    public init(seed: SeedInstaller, downloadsRoot: URL) {
        self.seed = seed
        self.downloadsRoot = downloadsRoot
        FileStaging.cleanupStaleStaging(in: downloadsRoot)
    }

    public func allCourses() -> [StoredCourse] {
        var result: [StoredCourse] = []
        for directory in seed.courseDirectories() {
            if let stored = load(from: directory, origin: .seed, revision: 0, releaseId: nil) {
                result.append(stored)
            }
        }
        let downloaded = (try? FileManager.default.contentsOfDirectory(
            at: downloadsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for courseDir in downloaded {
            let releaseDirs = (try? FileManager.default.contentsOfDirectory(
                at: courseDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            let selected = releaseDirs
                .compactMap { url -> (Int, URL)? in
                    let revision = Int(url.lastPathComponent) ?? 0
                    return (revision, url)
                }
                .max { lhs, rhs in lhs.0 < rhs.0 }
            if let selected,
               let stored = load(
                   from: selected.1,
                   origin: .downloaded,
                   revision: selected.0,
                   releaseId: selected.1.lastPathComponent
               ) {
                result.append(stored)
            }
        }
        return result
    }

    public func audioURL(for item: ItemV1, in stored: StoredCourse) -> URL? {
        guard let relative = item.audio?.relativePath else { return nil }
        return stored.directory.appendingPathComponent(relative)
    }

    private func load(
        from directory: URL,
        origin: StoredCourseOrigin,
        revision: Int,
        releaseId: String?
    ) -> StoredCourse? {
        let index = directory.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: index) else { return nil }
        do {
            let decoded = try ContentDecoder.decodeCourse(from: data)
            let metaURL = directory.appendingPathComponent(ReleaseMeta.fileName)
            let inheritSRS: Bool
            if let metaData = try? Data(contentsOf: metaURL),
               let meta = try? JSONDecoder().decode(ReleaseMeta.self, from: metaData) {
                inheritSRS = meta.inheritSRS
            } else {
                inheritSRS = true
            }
            return StoredCourse(
                course: CourseMigrator.migrate(decoded),
                origin: origin,
                directory: directory,
                revision: revision,
                releaseId: releaseId,
                inheritSRS: inheritSRS
            )
        } catch {
            return nil
        }
    }
}
