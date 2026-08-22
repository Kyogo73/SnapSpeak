import Foundation

/// String Catalog の明示キーに対する `String(format:)` ラッパ。
/// キー名に `%lld` を含めず、カタログ側のプレースホルダだけを使う。
public enum LocalizedFormat {
    public static func string(_ key: String, bundle: Bundle = .main, _ arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(stringLiteral: key), bundle: bundle)
        return String(format: format, locale: .autoupdatingCurrent, arguments: arguments)
    }
}
