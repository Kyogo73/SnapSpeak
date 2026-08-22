import AVFoundation
import Foundation

/// 単発ファイル再生。速度変更・録音タップなし。`AVAudioFile` オープン失敗は throw。
public final class SequenceFilePlayer: PhaseFilePlaying, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var continuationConsumed = false
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
            continuation = cont
            continuationConsumed = false
            lock.unlock()
            player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.finish(.success(()))
            }
            player.play()
        }
    }

    public func stop() {
        if player.isPlaying { player.stop() }
        if engine.isRunning { engine.stop() }
        finish(.failure(SpeechSynthesisError.cancelled))
    }

    private func attachIfNeeded() {
        guard !attached else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        attached = true
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        guard !continuationConsumed, let continuation else {
            lock.unlock()
            return
        }
        continuationConsumed = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}
