import ContentCore
import Foundation

public enum StoredCourseOrigin: String, Sendable, Equatable {
    case seed
    case downloaded
}

public struct StoredCourse: Sendable, Equatable {
    public var course: Course
    public var origin: StoredCourseOrigin
    public var directory: URL
    public var revision: Int
    public var releaseId: String?

    public init(
        course: Course,
        origin: StoredCourseOrigin,
        directory: URL,
        revision: Int,
        releaseId: String?
    ) {
        self.course = course
        self.origin = origin
        self.directory = directory
        self.revision = revision
        self.releaseId = releaseId
    }
}

/// Enumerates seed + downloaded courses. Unknown schema versions are skipped (keep local).
public actor CourseStore {
    private let seed: SeedInstaller
    private let downloadsRoot: URL

    public init(seed: SeedInstaller, downloadsRoot: URL) {
        self.seed = seed
        self.downloadsRoot = downloadsRoot
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
            return StoredCourse(
                course: CourseMigrator.migrate(decoded),
                origin: origin,
                directory: directory,
                revision: revision,
                releaseId: releaseId
            )
        } catch {
            return nil
        }
    }
}
