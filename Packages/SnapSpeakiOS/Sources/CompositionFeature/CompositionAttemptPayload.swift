import CompositionKit
import Foundation

/// 瞬間英作文 Attempt の `payloadJSON`。未リリースのため互換不要。`payloadSchemaVersion` は 1。
public struct CompositionAttemptPayload: Codable, Sendable, Equatable {
    public var payloadSchemaVersion: Int
    public var result: String
    public var usedHint: Bool
    public var latencyMs: Int

    public init(
        payloadSchemaVersion: Int = 1,
        result: String,
        usedHint: Bool,
        latencyMs: Int
    ) {
        self.payloadSchemaVersion = payloadSchemaVersion
        self.result = result
        self.usedHint = usedHint
        self.latencyMs = latencyMs
    }

    public static func resultLabel(for grade: CompositionGrade) -> String {
        switch grade {
        case .pass:
            return "pass"
        case .fail:
            return "fail"
        case .unscored:
            return "unscored"
        }
    }
}
