@testable import AudioEngine
import Foundation
import Testing

@Suite("RequestBoundContinuation")
struct RequestBoundContinuationTests {
    @Test("M4 古い ID の callback は新しい continuation を完了しない")
    func staleIDDoesNotCompleteNewRequest() async throws {
        let box = ContinuationBox()
        let first = Task {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                box.begin(cont)
            }
        }
        await waitUntil { box.currentID != nil }
        let staleID = try #require(box.currentID)
        let second = Task {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                box.begin(cont)
            }
        }
        await waitUntil { box.currentID != staleID }
        await #expect(throws: SpeechSynthesisError.cancelled) {
            try await first.value
        }
        box.complete(id: staleID, .success(()))
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(second.isCancelled == false)
        let liveID = try #require(box.currentID)
        box.complete(id: liveID, .success(()))
        try await second.value
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var bound = RequestBoundContinuation()
    private var storedID: UUID?

    var currentID: UUID? {
        lock.lock()
        defer { lock.unlock() }
        return storedID
    }

    func begin(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        storedID = bound.begin(continuation)
        lock.unlock()
    }

    func complete(id: UUID, _ result: Result<Void, Error>) {
        lock.lock()
        bound.complete(id: id, result)
        lock.unlock()
    }
}
