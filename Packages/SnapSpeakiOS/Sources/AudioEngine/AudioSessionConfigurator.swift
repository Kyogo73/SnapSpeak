import AVFoundation

public protocol AudioSessionConfiguring: Sendable {
    func activatePreview() throws
    func deactivate() throws
}

public struct AudioSessionConfigurator: AudioSessionConfiguring, Sendable {
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
            // `.allowBluetoothHFP` is not in the Xcode 16.4 SDK used by CI.
            // `.allowBluetooth` is the HFP-capable option on that SDK; revisit when CI moves past 16.4.
            options.insert(.allowBluetooth)
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
