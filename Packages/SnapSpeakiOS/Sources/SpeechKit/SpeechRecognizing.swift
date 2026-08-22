import Foundation

/// オンデバイス認識の最小シーム。空 transcript / throw を注入できる。
public protocol SpeechRecognizing: Sendable {
    func recognize(
        url: URL,
        locale: Locale,
        timeout: TimeInterval
    ) async throws -> [SpeechTranscriptSegment]
}

extension SpeechClient: SpeechRecognizing {}
