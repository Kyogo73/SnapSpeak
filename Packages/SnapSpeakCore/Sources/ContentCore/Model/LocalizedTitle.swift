import Foundation
import LanguageKit

public enum LocalizedTitle: Sendable {
    /// requested → sourceLanguage → `en`.
    public static func resolve(
        _ title: [String: String],
        requested: BCP47Language,
        sourceLanguage: BCP47Language
    ) -> String? {
        if let value = title[requested.raw] { return value }
        if let value = title[sourceLanguage.raw] { return value }
        return title["en"]
    }
}
