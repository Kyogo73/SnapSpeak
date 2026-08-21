import AVFoundation

public struct VoiceProcessingResult: Sendable, Equatable {
    public var enabled: Bool
    public var failureDescription: String?

    public init(enabled: Bool, failureDescription: String? = nil) {
        self.enabled = enabled
        self.failureDescription = failureDescription
    }

    public static let disabled = VoiceProcessingResult(enabled: false)
}

/// Voice Processing must be toggled on a *stopped* engine, never on running nodes.
public enum VoiceProcessing {
    public static func enable(on engine: AVAudioEngine) -> VoiceProcessingResult {
        guard !engine.isRunning else {
            return VoiceProcessingResult(
                enabled: false,
                failureDescription: "engine-running"
            )
        }
        do {
            try engine.inputNode.setVoiceProcessingEnabled(true)
            return VoiceProcessingResult(enabled: true)
        } catch {
            return VoiceProcessingResult(
                enabled: false,
                failureDescription: error.localizedDescription
            )
        }
    }
}
