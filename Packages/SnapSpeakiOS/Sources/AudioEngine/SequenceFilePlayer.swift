import AVFoundation
import Foundation

/// 単発ファイル再生。速度変更・録音タップなし。`AVAudioFile` オープン失敗は throw。
/// schedule callback は play 要求 ID と照合し、古い完了が新しい再生を閉じない。
public final class SequenceFilePlayer: PhaseFilePlaying, @unchecked Sendable {
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private let lock = NSLock()
    private var bound = RequestBoundContinuation()
    private var playID: UUID?
    private var attached = false

    public init() {}

    public func play(url: URL) async throws {
        stop()
        let file = try AVAudioFile(forReading: url)
        attachIfNeeded()
        if !engine.isRunning {
            try engine.start()
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            lock.lock()
            let id = bound.begin(cont)
            playID = id
            lock.unlock()
            player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.finish(id: id, .success(()))
            }
            player.play()
        }
    }

    public func stop() {
        if player.isPlaying { player.stop() }
        if engine.isRunning { engine.stop() }
        lock.lock()
        bound.completeCurrent(.failure(SpeechSynthesisError.cancelled))
        playID = nil
        lock.unlock()
    }

    public func resetEngine() {
        stop()
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        attached = false
    }

    private func attachIfNeeded() {
        guard !attached else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        attached = true
    }

    private func finish(id: UUID, _ result: Result<Void, Error>) {
        lock.lock()
        guard playID == id else {
            lock.unlock()
            return
        }
        playID = nil
        bound.complete(id: id, result)
        lock.unlock()
    }
}
