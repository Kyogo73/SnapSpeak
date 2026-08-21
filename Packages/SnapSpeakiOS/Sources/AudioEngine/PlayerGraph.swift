import AVFoundation

/// `AVAudioPlayerNode` + `AVAudioUnitTimePitch` (rate 0.5–1.5, pitch = 0 cents).
public final class PlayerGraph: @unchecked Sendable {
    public static let minimumRate: Float = 0.5
    public static let maximumRate: Float = 1.5

    public let engine = AVAudioEngine()
    public let player = AVAudioPlayerNode()
    public let timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private var recordingFile: AVAudioFile?
    private var tapInstalled = false
    private var nodesAttached = false

    public init() {}

    public static func clampedRate(_ rate: Float) -> Float {
        min(max(rate, minimumRate), maximumRate)
    }

    public func attachPlayback(rate: Float) throws {
        teardown()
        timePitch.rate = Self.clampedRate(rate)
        timePitch.pitch = 0
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
        nodesAttached = true
    }

    public func attachRecordOnly() throws {
        teardown()
        nodesAttached = false
    }

    public func setRate(_ rate: Float) {
        timePitch.rate = Self.clampedRate(rate)
        timePitch.pitch = 0
    }

    public func scheduleAndPlay(fileURL: URL, atHostSeconds hostSeconds: TimeInterval) throws {
        let file = try AVAudioFile(forReading: fileURL)
        audioFile = file
        let start = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: hostSeconds))
        player.scheduleFile(file, at: start, completionHandler: nil)
        player.play(at: start)
    }

    public func installInputTap(to url: URL) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        recordingFile = try AVAudioFile(forWriting: url, settings: format.settings)
        input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
            try? self?.recordingFile?.write(from: buffer)
        }
        tapInstalled = true
    }

    public func startEngine() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    public func pause() {
        if player.isPlaying { player.pause() }
    }

    public func resume() {
        if nodesAttached { player.play() }
    }

    public func teardown() {
        if engine.isRunning { engine.stop() }
        if player.isPlaying { player.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recordingFile = nil
        audioFile = nil
        if nodesAttached {
            engine.disconnectNodeOutput(player)
            engine.disconnectNodeOutput(timePitch)
            engine.detach(player)
            engine.detach(timePitch)
            nodesAttached = false
        }
        engine.reset()
    }
}
