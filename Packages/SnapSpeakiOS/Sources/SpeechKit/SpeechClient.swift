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
    // SFSpeechRecognizer / SFSpeechURLRecognitionRequest are non-Sendable; they never
    // leave this actor's isolation. Keeping them as actor-isolated state (rather than
    // passing them into @Sendable task closures) satisfies Swift 6 strict concurrency.
    private var currentTask: SFSpeechRecognitionTask?
    private var pendingRecognizer: SFSpeechRecognizer?
    private var pendingRequest: SFSpeechURLRecognitionRequest?

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
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechClientError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        pendingRecognizer = recognizer
        pendingRequest = request
        defer {
            pendingRecognizer = nil
            pendingRequest = nil
        }

        do {
            return try await withThrowingTaskGroup(of: [SpeechTranscriptSegment].self) { group in
                group.addTask { try await self.perform() }
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

    private func perform() async throws -> [SpeechTranscriptSegment] {
        guard let recognizer = pendingRecognizer, let request = pendingRequest else {
            throw SpeechClientError.recognitionFailed
        }
        return try await withCheckedThrowingContinuation { continuation in
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
            // Executed synchronously within the actor's isolation, so this is safe.
            currentTask = task
        }
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
