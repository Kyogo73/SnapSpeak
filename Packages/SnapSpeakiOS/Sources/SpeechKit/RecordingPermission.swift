import AVFoundation
import Foundation
import Speech

public enum MediaPermission: Sendable, Equatable {
    case undetermined
    case authorized
    case denied
}

public struct RecordingPermission: Sendable, Equatable {
    public var microphone: MediaPermission
    public var speech: MediaPermission

    public init(microphone: MediaPermission, speech: MediaPermission) {
        self.microphone = microphone
        self.speech = speech
    }

    public var canRecord: Bool { microphone == .authorized }
    public var canTranscribe: Bool { canRecord && speech == .authorized }
}

public protocol RecordingPermissionClient: Sendable {
    func microphoneStatus() -> MediaPermission
    func requestMicrophone() async -> MediaPermission
    func speechStatus() -> MediaPermission
    func requestSpeech() async -> MediaPermission
}

/// 録音直前の JIT 権限コーディネーション（未決定→要求、拒否はそのまま返す）。
public enum RecordingPermissionCoordinator {
    public static func prepare(client: any RecordingPermissionClient) async -> RecordingPermission {
        var microphone = client.microphoneStatus()
        if microphone == .undetermined {
            microphone = await client.requestMicrophone()
        }
        var speech = client.speechStatus()
        if microphone == .authorized, speech == .undetermined {
            speech = await client.requestSpeech()
        }
        return RecordingPermission(microphone: microphone, speech: speech)
    }
}

public struct LiveRecordingPermissionClient: RecordingPermissionClient {
    public init() {}

    public func microphoneStatus() -> MediaPermission {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            return .undetermined
        case .granted:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    public func requestMicrophone() async -> MediaPermission {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted ? .authorized : .denied)
            }
        }
    }

    public func speechStatus() -> MediaPermission {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .undetermined
        @unknown default:
            return .denied
        }
    }

    public func requestSpeech() async -> MediaPermission {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .authorized)
                case .denied, .restricted:
                    continuation.resume(returning: .denied)
                case .notDetermined:
                    continuation.resume(returning: .undetermined)
                @unknown default:
                    continuation.resume(returning: .denied)
                }
            }
        }
    }
}
