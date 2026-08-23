import Foundation

/// 要求 ID と continuation を 1:1 で結び、古い callback が新しい要求を完了しないようにする。
struct RequestBoundContinuation: Sendable {
    private var requestID: UUID?
    private var continuation: CheckedContinuation<Void, Error>?

    mutating func begin(_ continuation: CheckedContinuation<Void, Error>) -> UUID {
        if let existing = self.continuation {
            existing.resume(throwing: SpeechSynthesisError.cancelled)
        }
        let id = UUID()
        requestID = id
        self.continuation = continuation
        return id
    }

    mutating func complete(id: UUID, _ result: Result<Void, Error>) {
        guard requestID == id, let continuation else { return }
        requestID = nil
        self.continuation = nil
        continuation.resume(with: result)
    }

    mutating func completeCurrent(_ result: Result<Void, Error>) {
        guard let id = requestID else { return }
        complete(id: id, result)
    }
}
