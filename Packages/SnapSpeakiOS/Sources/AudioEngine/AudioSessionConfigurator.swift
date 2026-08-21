import AVFoundation

public struct AudioSessionConfigurator: Sendable {
    public init() {}

    /// Preview: `.playback` + `.spokenAudio`. Never combine `.spokenAudio` with playAndRecord.
    public func activatePreview() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
        try session.setActive(true)
    }

    /// Simultaneous or record-only: `.playAndRecord` + `.voiceChat`.
    public func activatePlayAndRecord(defaultToSpeaker: Bool, allowBluetoothHFP: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = []
        if defaultToSpeaker {
            options.insert(.defaultToSpeaker)
        }
        if allowBluetoothHFP {
            options.insert(.allowBluetoothHFP)
        }
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try session.setActive(true)
    }

    public func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }
}
