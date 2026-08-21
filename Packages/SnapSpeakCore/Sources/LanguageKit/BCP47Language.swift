import Foundation

/// Normalized BCP-47 language tag (language / Script / REGION).
public struct BCP47Language: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: String

    public var description: String { raw }

    public var languageSubtag: String {
        raw.split(separator: "-").first.map(String.init) ?? raw
    }

    public static let english: BCP47Language = {
        do {
            return try BCP47Language("en")
        } catch {
            preconditionFailure("en is a valid BCP-47 tag")
        }
    }()

    public init(_ tag: String) throws {
        self.raw = try Self.normalize(tag)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let tag = try container.decode(String.self)
        self.raw = try Self.normalize(tag)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    /// Returns true when `tag` is already in canonical BCP-47 form.
    public static func isNormalized(_ tag: String) -> Bool {
        (try? normalize(tag)) == tag
    }

    public static func normalize(_ tag: String) throws -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BCP47LanguageError.invalidTag(tag)
        }
        let subtags = trimmed.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard subtags.allSatisfy({ !$0.isEmpty }) else {
            throw BCP47LanguageError.invalidTag(tag)
        }

        var result: [String] = []
        for (index, subtag) in subtags.enumerated() {
            guard subtag.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
                throw BCP47LanguageError.invalidTag(tag)
            }
            if index == 0 {
                guard (2...8).contains(subtag.count), subtag.allSatisfy(\.isLetter) else {
                    throw BCP47LanguageError.invalidTag(tag)
                }
                result.append(subtag.lowercased())
                continue
            }
            if subtag.count == 4, subtag.allSatisfy(\.isLetter) {
                let script = subtag.prefix(1).uppercased() + subtag.dropFirst().lowercased()
                result.append(script)
            } else if subtag.count == 2, subtag.allSatisfy(\.isLetter) {
                result.append(subtag.uppercased())
            } else if subtag.count == 3, subtag.allSatisfy(\.isNumber) {
                result.append(subtag)
            } else if (5...8).contains(subtag.count), subtag.allSatisfy(\.isLetter) {
                result.append(subtag.lowercased())
            } else if (2...8).contains(subtag.count), subtag.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
                result.append(subtag.lowercased())
            } else {
                throw BCP47LanguageError.invalidTag(tag)
            }
        }
        return result.joined(separator: "-")
    }
}

public enum BCP47LanguageError: Error, Equatable, Sendable {
    case invalidTag(String)
}
