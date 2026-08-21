import AVFoundation
import ScoringKit

public enum AudioRouteKind: String, Sendable, Equatable {
    case wiredHeadset
    case builtInReceiver
    case builtInSpeaker
    case bluetooth
    case otherHFP
    case unknown
}

public struct RouteDecision: Sendable, Equatable {
    public var kind: AudioRouteKind
    public var allowSimultaneousScoring: Bool
    public var isDegraded: Bool
    public var requiresVoiceProcessing: Bool
    public var defaultToSpeaker: Bool
    public var allowBluetoothHFP: Bool
    public var inputPortName: String
    public var outputPortName: String
    public var isHFP: Bool

    public init(
        kind: AudioRouteKind,
        allowSimultaneousScoring: Bool,
        isDegraded: Bool,
        requiresVoiceProcessing: Bool,
        defaultToSpeaker: Bool,
        allowBluetoothHFP: Bool,
        inputPortName: String,
        outputPortName: String,
        isHFP: Bool
    ) {
        self.kind = kind
        self.allowSimultaneousScoring = allowSimultaneousScoring
        self.isDegraded = isDegraded
        self.requiresVoiceProcessing = requiresVoiceProcessing
        self.defaultToSpeaker = defaultToSpeaker
        self.allowBluetoothHFP = allowBluetoothHFP
        self.inputPortName = inputPortName
        self.outputPortName = outputPortName
        self.isHFP = isHFP
    }

    public func degradedDisablingSimultaneous() -> RouteDecision {
        var copy = self
        copy.allowSimultaneousScoring = false
        copy.isDegraded = true
        copy.allowBluetoothHFP = false
        return copy
    }

    public func snapshot(voiceProcessingEnabled: Bool) -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            inputPortName: inputPortName,
            outputPortName: outputPortName,
            isHFP: isHFP,
            voiceProcessingEnabled: voiceProcessingEnabled
        )
    }
}

/// Architecture §3.2 route table → `RouteDecision`.
public enum RoutePolicy {
    public static let idleDecision = RouteDecision(
        kind: .unknown,
        allowSimultaneousScoring: false,
        isDegraded: false,
        requiresVoiceProcessing: false,
        defaultToSpeaker: false,
        allowBluetoothHFP: false,
        inputPortName: "",
        outputPortName: "",
        isHFP: false
    )

    public static func decide(session: AVAudioSession = .sharedInstance()) -> RouteDecision {
        let input = session.currentRoute.inputs.first
        let output = session.currentRoute.outputs.first
        return decide(
            inputPort: input?.portType,
            outputPort: output?.portType,
            inputPortName: input?.portName ?? "",
            outputPortName: output?.portName ?? ""
        )
    }

    public static func decide(
        inputPort: AVAudioSession.Port?,
        outputPort: AVAudioSession.Port?,
        inputPortName: String,
        outputPortName: String
    ) -> RouteDecision {
        let isHFP = inputPort == .bluetoothHFP || outputPort == .bluetoothHFP
        let kind = classify(inputPort: inputPort, outputPort: outputPort, isHFP: isHFP)
        switch kind {
        case .wiredHeadset:
            return RouteDecision(
                kind: kind,
                allowSimultaneousScoring: true,
                isDegraded: false,
                requiresVoiceProcessing: true,
                defaultToSpeaker: false,
                allowBluetoothHFP: false,
                inputPortName: inputPortName,
                outputPortName: outputPortName,
                isHFP: false
            )
        case .builtInReceiver:
            return RouteDecision(
                kind: kind,
                allowSimultaneousScoring: true,
                isDegraded: false,
                requiresVoiceProcessing: true,
                defaultToSpeaker: false,
                allowBluetoothHFP: false,
                inputPortName: inputPortName,
                outputPortName: outputPortName,
                isHFP: false
            )
        case .builtInSpeaker:
            return RouteDecision(
                kind: kind,
                allowSimultaneousScoring: true,
                isDegraded: false,
                requiresVoiceProcessing: true,
                defaultToSpeaker: true,
                allowBluetoothHFP: false,
                inputPortName: inputPortName,
                outputPortName: outputPortName,
                isHFP: false
            )
        case .bluetooth:
            return RouteDecision(
                kind: kind,
                allowSimultaneousScoring: isHFP,
                isDegraded: true,
                requiresVoiceProcessing: true,
                defaultToSpeaker: false,
                allowBluetoothHFP: isHFP,
                inputPortName: inputPortName,
                outputPortName: outputPortName,
                isHFP: isHFP
            )
        case .otherHFP:
            return RouteDecision(
                kind: kind,
                allowSimultaneousScoring: false,
                isDegraded: true,
                requiresVoiceProcessing: true,
                defaultToSpeaker: false,
                allowBluetoothHFP: true,
                inputPortName: inputPortName,
                outputPortName: outputPortName,
                isHFP: true
            )
        case .unknown:
            return RouteDecision(
                kind: kind,
                allowSimultaneousScoring: false,
                isDegraded: true,
                requiresVoiceProcessing: true,
                defaultToSpeaker: false,
                allowBluetoothHFP: false,
                inputPortName: inputPortName,
                outputPortName: outputPortName,
                isHFP: isHFP
            )
        }
    }

    private static func classify(
        inputPort: AVAudioSession.Port?,
        outputPort: AVAudioSession.Port?,
        isHFP: Bool
    ) -> AudioRouteKind {
        if outputPort == .headphones || outputPort == .headsetMic || inputPort == .headsetMic {
            return .wiredHeadset
        }
        if outputPort == .builtInReceiver {
            return .builtInReceiver
        }
        if outputPort == .builtInSpeaker {
            return .builtInSpeaker
        }
        let bluetoothOutputs: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        if let outputPort, bluetoothOutputs.contains(outputPort) {
            return .bluetooth
        }
        if isHFP {
            return .otherHFP
        }
        return .unknown
    }
}
