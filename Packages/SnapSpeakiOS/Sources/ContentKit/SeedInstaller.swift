import ContentCore
import Foundation

/// Reads bundled `Seed/` courses in place. No copy on first launch.
public struct SeedInstaller: Sendable {
    public var bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func seedRootURL() -> URL? {
        bundle.url(forResource: "Seed", withExtension: nil)
    }

    public func courseDirectories() -> [URL] {
        guard let root = seedRootURL() else { return [] }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.filter { url in
            let isDirectory = ((try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory) ?? false
            let hasIndex = FileManager.default.fileExists(
                atPath: url.appendingPathComponent("index.json").path
            )
            return isDirectory && hasIndex
        }
    }

    public func loadCourses() -> [Course] {
        courseDirectories().compactMap { directory in
            let index = directory.appendingPathComponent("index.json")
            guard let data = try? Data(contentsOf: index) else { return nil }
            do {
                let decoded = try ContentDecoder.decodeCourse(from: data)
                return CourseMigrator.migrate(decoded)
            } catch {
                return nil
            }
        }
    }
}
