import Foundation
import LanguageKit

public struct ContentValidator: Sendable {
    public static let maxDurationMs = 50_000

    public init() {}

    public func validate(_ course: CourseV1) -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        if !BCP47Language.isNormalized(course.languagePair.sourceLanguage.raw)
            || !BCP47Language.isNormalized(course.languagePair.targetLanguage.raw) {
            errors.append(.languagePairNotNormalized(course.languagePair.pairKey))
        }

        var seenIDs: Set<String> = []
        for unit in course.units {
            for lesson in unit.lessons {
                for item in lesson.items {
                    if seenIDs.contains(item.id) {
                        errors.append(.duplicateItemID(item.id))
                    }
                    seenIDs.insert(item.id)

                    if item.kind == .shadowing, item.audio == nil {
                        errors.append(.shadowingAudioRequired(itemId: item.id))
                    }
                    if let audio = item.audio, audio.durationMs > Self.maxDurationMs {
                        errors.append(.durationTooLong(itemId: item.id, durationMs: audio.durationMs))
                    }
                    if let passage = item.passage {
                        if !isMonotonic(passage.captionSegments) {
                            errors.append(.captionNotMonotonic(itemId: item.id))
                        }
                    }
                }
            }
        }
        return errors
    }

    public func verifyAudioChecksums(course: CourseV1, audioRoot: URL) -> [ContentValidationError] {
        var errors: [ContentValidationError] = []
        for unit in course.units {
            for lesson in unit.lessons {
                for item in lesson.items {
                    guard let audio = item.audio else { continue }
                    let fileURL = audioRoot.appendingPathComponent(audio.relativePath)
                    guard let data = try? Data(contentsOf: fileURL) else {
                        errors.append(.audioFileMissing(path: audio.relativePath))
                        continue
                    }
                    if !Checksum.verify(data: data, expectedHex: audio.checksumSha256) {
                        errors.append(.checksumMismatch(path: audio.relativePath))
                    }
                }
            }
        }
        return errors
    }

    private func isMonotonic(_ segments: [CaptionSegment]) -> Bool {
        var previousEnd = 0
        for segment in segments {
            if segment.startMs < previousEnd { return false }
            if segment.endMs <= segment.startMs { return false }
            previousEnd = segment.endMs
        }
        return true
    }
}
