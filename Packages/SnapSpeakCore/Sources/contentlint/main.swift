import Foundation
import ContentCore

@main
enum ContentLint {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        var indexPaths: [String] = []
        var manifestPath: String?
        var audioRoot: String?
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "--manifest" {
                index += 1
                guard index < args.count else { failUsage("missing value for --manifest") }
                manifestPath = args[index]
            } else if arg == "--audio-root" {
                index += 1
                guard index < args.count else { failUsage("missing value for --audio-root") }
                audioRoot = args[index]
            } else if arg.hasPrefix("-") {
                failUsage("unknown option: \(arg)")
            } else {
                indexPaths.append(arg)
            }
            index += 1
        }

        guard !indexPaths.isEmpty else {
            failUsage("contentlint <index.json>... [--manifest <m.json>] [--audio-root <dir>]")
        }

        var failed = false
        for path in indexPaths {
            do {
                try lintIndex(path: path, audioRoot: audioRoot)
            } catch {
                eprint("error: \(path): \(error)")
                failed = true
            }
        }

        if let manifestPath {
            do {
                try lintManifest(path: manifestPath)
            } catch {
                eprint("error: \(manifestPath): \(error)")
                failed = true
            }
        }

        if failed { exit(1) }
        exit(0)
    }

    private static func lintIndex(path: String, audioRoot: String?) throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let course = try ContentDecoder.decodeCourse(from: data)
        _ = CourseMigrator.migrate(course)
        let validator = ContentValidator()
        var errors = validator.validate(course)
        if let audioRoot {
            errors.append(contentsOf: validator.verifyAudioChecksums(
                course: course,
                audioRoot: URL(fileURLWithPath: audioRoot)
            ))
        }
        if !errors.isEmpty {
            for error in errors {
                eprint("validation: \(error)")
            }
            throw ExitFailure()
        }
        print("ok: \(path) id=\(course.id) schema=\(course.schemaVersion)")
    }

    private static func lintManifest(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let manifest = try Manifest.decode(from: data)
        print("ok: manifest schema=\(manifest.manifestSchemaVersion) courses=\(manifest.courses.count)")
    }

    private static func failUsage(_ message: String) -> Never {
        eprint(message)
        exit(2)
    }

    private static func eprint(_ message: String) {
        let line = message + "\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}

private struct ExitFailure: Error {}
