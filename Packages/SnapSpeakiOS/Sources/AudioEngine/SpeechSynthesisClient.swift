import AVFoundation
import Foundation

/// `AVSpeechSynthesizerDelegate` を continuation で async 化する。
/// Delegate は non-Sendable のため最小の `@unchecked Sendable` 箱に閉じる。
public final class SpeechSynthesisClient: SpeechSynthesizing, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private let box = SpeechSynthesisDelegateBox()
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var continuationConsumed = false

    public init() {
        synthesizer.delegate = box
        box.owner = self
    }

    public func speak(text: String, languageTag: String) async throws {
        guard AVSpeechSynthesisVoice(language: languageTag) != nil else {
            throw SpeechSynthesisError.voiceUnavailable
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            lock.lock()
            continuation = cont
            continuationConsumed = false
            lock.unlock()
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: languageTag)
            synthesizer.speak(utterance)
        }
    }

    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        finish(.failure(SpeechSynthesisError.cancelled))
    }

    fileprivate func finish(_ result: Result<Void, Error>) {
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

private final class SpeechSynthesisDelegateBox: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    weak var owner: SpeechSynthesisClient?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        _ = synthesizer
        _ = utterance
        owner?.finish(.success(()))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        _ = synthesizer
        _ = utterance
        owner?.finish(.failure(SpeechSynthesisError.cancelled))
    }
}
