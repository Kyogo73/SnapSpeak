import Foundation

public let KnownContentSchemaVersions: [Int] = [1]

public enum ContentDecodingError: Error, Equatable, Sendable {
    case unknownSchemaVersion(found: Int, known: [Int])
    case oneOfViolation(itemId: String, reason: String)
    case missingLanguagePair
    case invalidLanguageTag(String)
    case languageTagNotNormalized(String)
    case missingField(String)
}

public enum ContentValidationError: Error, Equatable, Sendable {
    case captionNotMonotonic(itemId: String)
    case duplicateItemID(String)
    case shadowingAudioRequired(itemId: String)
    case durationTooLong(itemId: String, durationMs: Int)
    case languagePairNotNormalized(String)
    case checksumMismatch(path: String)
    case audioFileMissing(path: String)
}
