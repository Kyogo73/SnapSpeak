import Foundation

/// SpeechKit-local transcript DTO. Feature maps this to ScoringKit.`ASRSegment`.
/// SpeechKit cannot import ScoringKit (Package.swift: LanguageKit only).
public struct SpeechTranscriptSegment: Sendable, Equatable {
    public var text: String
    public var timestamp: Double
    public var duration: Double
    public var confidence: Double

    public init(text: String, timestamp: Double, duration: Double, confidence: Double) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.confidence = confidence
    }
}
