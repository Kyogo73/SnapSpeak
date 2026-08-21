import Foundation

public protocol TextNormalizer: Sendable {
    func normalize(_ text: String) -> String
}

/// English L2 normalizer. Stage order is fixed (architecture §5.1):
/// NFKC → lowercase → smart quotes → strip punctuation (keep apostrophes) → expand contractions → collapse whitespace.
public struct EnglishNormalizer: TextNormalizer {
    public init() {}

    public func normalize(_ text: String) -> String {
        var value = text.precomposedStringWithCompatibilityMapping
        value = value.lowercased()
        value = Self.replaceSmartQuotes(value)
        value = Self.stripPunctuationKeepingApostrophes(value)
        value = EnglishContractions.expandAll(in: value)
        value = Self.collapseWhitespace(value)
        return value
    }

    private static func replaceSmartQuotes(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x2018, 0x2019, 0x201A, 0x201B, 0x2032, 0x00B4, 0x0060:
                scalars.append("'")
            case 0x201C, 0x201D, 0x201E, 0x201F, 0x2033:
                scalars.append("\"")
            default:
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private static func stripPunctuationKeepingApostrophes(_ text: String) -> String {
        text.unicodeScalars.map { scalar in
            if scalar == "'" { return Character("'") }
            if CharacterSet.punctuationCharacters.contains(scalar)
                || CharacterSet.symbols.contains(scalar) {
                return Character(" ")
            }
            return Character(scalar)
        }.reduce(into: "") { $0.append($1) }
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split { $0.isWhitespace || $0.isNewline }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
