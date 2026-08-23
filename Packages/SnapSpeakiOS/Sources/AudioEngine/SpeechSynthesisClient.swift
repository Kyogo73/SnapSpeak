import AVFoundation
import Foundation

/// `AVSpeechSynthesizerDelegate` を continuation で async 化する。
/// Delegate は non-Sendable のため最小の `@unchecked Sendable` 箱に閉じる。
/// 要求 ID 照合で古い didFinish / didCancel が新しい発話を完了しない。
public final class SpeechSynthesisClient: SpeechSynthesizing, @unchecked Sendable {
    private var synthesizer = AVSpeechSynthesizer()
    private let box = SpeechSynthesisDelegateBox()
    private let lock = NSLock()
    private var bound = RequestBoundContinuation()
    private var utteranceIDs: [ObjectIdentifier: UUID] = [:]

    public init() {
        synthesizer.delegate = box
        box.owner = self
    }

    public func speak(text: String, languageTag: String) async throws {
        guard AVSpeechSynthesisVoice(language: languageTag) != nil else {
            throw SpeechSynthesisError.voiceUnavailable
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: languageTag)
            lock.lock()
            let id = bound.begin(cont)
            utteranceIDs[ObjectIdentifier(utterance)] = id
            lock.unlock()
            synthesizer.speak(utterance)
        }
    }

    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        lock.lock()
        bound.completeCurrent(.failure(SpeechSynthesisError.cancelled))
        lock.unlock()
    }

    public func resetEngine() {
        stopSpeaking()
        let next = AVSpeechSynthesizer()
        next.delegate = box
        synthesizer = next
    }

    fileprivate func finish(utterance: AVSpeechUtterance, _ result: Result<Void, Error>) {
        lock.lock()
        let id = utteranceIDs.removeValue(forKey: ObjectIdentifier(utterance))
        if let id {
            bound.complete(id: id, result)
        }
        lock.unlock()
    }
}

private final class SpeechSynthesisDelegateBox: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    weak var owner: SpeechSynthesisClient?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        _ = synthesizer
        owner?.finish(utterance: utterance, .success(()))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        _ = synthesizer
        owner?.finish(utterance: utterance, .failure(SpeechSynthesisError.cancelled))
    }
}
