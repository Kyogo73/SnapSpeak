import Foundation
import LanguageKit
import Speech

/// Four on-device ASR gates (architecture §3.7). All must pass or shadowing ASR is off.
public struct SpeechAvailability: Sendable, Equatable {
    public var localeSupported: Bool
    public var recognizerInitializable: Bool
    public var supportsOnDeviceRecognition: Bool
    public var isAvailable: Bool

    public init(
        localeSupported: Bool,
        recognizerInitializable: Bool,
        supportsOnDeviceRecognition: Bool,
        isAvailable: Bool
    ) {
        self.localeSupported = localeSupported
        self.recognizerInitializable = recognizerInitializable
        self.supportsOnDeviceRecognition = supportsOnDeviceRecognition
        self.isAvailable = isAvailable
    }

    public var isOnDeviceReady: Bool {
        localeSupported
            && recognizerInitializable
            && supportsOnDeviceRecognition
            && isAvailable
    }

    @MainActor
    public static func inspect(locale: Locale) -> SpeechAvailability {
        let supported = SFSpeechRecognizer.supportedLocales().contains { candidate in
            candidate.identifier == locale.identifier
        }
        let recognizer = SFSpeechRecognizer(locale: locale)
        return SpeechAvailability(
            localeSupported: supported,
            recognizerInitializable: recognizer != nil,
            supportsOnDeviceRecognition: recognizer?.supportsOnDeviceRecognition ?? false,
            isAvailable: recognizer?.isAvailable ?? false
        )
    }

    @MainActor
    public static func inspect(
        targetLanguage: BCP47Language,
        resolver: any SpeechLocaleResolver = StaticSpeechLocaleResolver()
    ) -> SpeechAvailability {
        guard let locale = resolver.speechLocale(for: targetLanguage, regionPreference: nil) else {
            return SpeechAvailability(
                localeSupported: false,
                recognizerInitializable: false,
                supportsOnDeviceRecognition: false,
                isAvailable: false
            )
        }
        return inspect(locale: locale)
    }
}
