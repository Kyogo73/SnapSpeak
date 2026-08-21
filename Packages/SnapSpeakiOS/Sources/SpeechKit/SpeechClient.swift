import Foundation
import Speech

public enum SpeechClientError: Error, Sendable, Equatable {
    case onDeviceUnavailable
    case timeout
    case canceled
    case recognitionFailed
}

/// On-device Speech only. There is intentionally no server-recognition fallback path.
public actor SpeechClient {
    private var currentTask: SFSpeechRecognitionTask?

    public init() {}

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    public func recognize(
        url: URL,
        locale: Locale,
        timeout: TimeInterval
    ) async throws -> [SpeechTranscriptSegment] {
        let availability = await SpeechAvailability.inspect(locale: locale)
        guard availability.isOnDeviceReady else {
            throw SpeechClientError.onDeviceUnavailable
        }
        let recognizer = await MainActor.run { SFSpeechRecognizer(locale: locale) }
        guard let recognizer else {
            throw SpeechClientError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        do {
            return try await withThrowingTaskGroup(of: [SpeechTranscriptSegment].self) { group in
                group.addTask {
                    try await self.perform(recognizer: recognizer, request: request)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw SpeechClientError.timeout
                }
                let result = try await group.next()
                group.cancelAll()
                guard let result else {
                    throw SpeechClientError.recognitionFailed
                }
                return result
            }
        } catch is CancellationError {
            cancel()
            throw SpeechClientError.canceled
        } catch {
            cancel()
            throw error
        }
    }

    private func perform(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async throws -> [SpeechTranscriptSegment] {
        try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce()
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    once.resume { continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                let segments = result.bestTranscription.segments.map { segment in
                    SpeechTranscriptSegment(
                        text: segment.substring,
                        timestamp: segment.timestamp,
                        duration: segment.duration,
                        confidence: Double(segment.confidence)
                    )
                }
                once.resume { continuation.resume(returning: segments) }
            }
            Task { await self.remember(task) }
        }
    }

    private func remember(_ task: SFSpeechRecognitionTask) {
        currentTask = task
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private var finished = false
    private let lock = NSLock()

    func resume(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        if finished { return }
        finished = true
        body()
    }
}
