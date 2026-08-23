import Foundation

/// ドライブ完了 Attempt の型付き payload（shadowing: 2 / composition: 3）。
public struct DriveAttemptPayload: Codable, Sendable, Equatable {
    public static let shadowingSchemaVersion = 2
    public static let compositionSchemaVersion = 3

    public var payloadSchemaVersion: Int
    public var context: String
    public var passIndex: Int
    public var usedTTSFallback: Bool
    public var speakPauseMs: Int?
    public var repeats: Int?

    public init(
        payloadSchemaVersion: Int,
        context: String = "drive",
        passIndex: Int,
        usedTTSFallback: Bool,
        speakPauseMs: Int? = nil,
        repeats: Int? = nil
    ) {
        self.payloadSchemaVersion = payloadSchemaVersion
        self.context = context
        self.passIndex = passIndex
        self.usedTTSFallback = usedTTSFallback
        self.speakPauseMs = speakPauseMs
        self.repeats = repeats
    }
}
