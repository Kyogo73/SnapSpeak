import CompositionKit
import Foundation

/// 瞬間英作文 Attempt の `payloadJSON`。
/// v0.1.0 は `{"payloadSchemaVersion":"1","passed":"..."}`。現行は v2（`result` / `usedHint` / `latencyMs`）。
public struct CompositionAttemptPayload: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 2

    public var payloadSchemaVersion: Int
    public var result: String
    public var usedHint: Bool
    public var latencyMs: Int

    public init(
        payloadSchemaVersion: Int = currentSchemaVersion,
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

    enum CodingKeys: String, CodingKey {
        case payloadSchemaVersion
        case result
        case usedHint
        case latencyMs
        case passed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try Self.decodeVersion(from: container)
        payloadSchemaVersion = version
        switch version {
        case Self.currentSchemaVersion:
            result = try container.decode(String.self, forKey: .result)
            usedHint = try container.decode(Bool.self, forKey: .usedHint)
            latencyMs = try container.decode(Int.self, forKey: .latencyMs)
        case 1:
            if let labeled = try container.decodeIfPresent(String.self, forKey: .result) {
                result = labeled
            } else {
                let passed = try container.decodeIfPresent(String.self, forKey: .passed) ?? "unscored"
                result = Self.result(fromPassed: passed)
            }
            usedHint = try container.decodeIfPresent(Bool.self, forKey: .usedHint) ?? false
            latencyMs = try container.decodeIfPresent(Int.self, forKey: .latencyMs) ?? 0
        default:
            // 未知の将来版数を v2 と誤解釈しない（ContentCore の schemaVersion 拒否と同じ方針）
            throw DecodingError.dataCorruptedError(
                forKey: .payloadSchemaVersion,
                in: container,
                debugDescription: "unknown payloadSchemaVersion \(version)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(payloadSchemaVersion, forKey: .payloadSchemaVersion)
        try container.encode(result, forKey: .result)
        try container.encode(usedHint, forKey: .usedHint)
        try container.encode(latencyMs, forKey: .latencyMs)
    }

    private static func decodeVersion(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> Int {
        if let version = try? container.decode(Int.self, forKey: .payloadSchemaVersion) {
            return version
        }
        if let raw = try? container.decode(String.self, forKey: .payloadSchemaVersion),
           let version = Int(raw) {
            return version
        }
        throw DecodingError.dataCorruptedError(
            forKey: .payloadSchemaVersion,
            in: container,
            debugDescription: "payloadSchemaVersion must be Int or numeric String"
        )
    }

    private static func result(fromPassed passed: String) -> String {
        switch passed {
        case "true":
            return "pass"
        case "false":
            return "fail"
        default:
            return "unscored"
        }
    }
}
