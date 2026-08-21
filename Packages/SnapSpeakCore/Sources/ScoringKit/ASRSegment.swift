import Foundation

/// Sendable DTO standing in for `SFTranscriptionSegment` so ScoringKit stays Foundation-only.
public struct ASRSegment: Sendable, Equatable {
    public var text: String
    /// Seconds relative to recording start.
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
