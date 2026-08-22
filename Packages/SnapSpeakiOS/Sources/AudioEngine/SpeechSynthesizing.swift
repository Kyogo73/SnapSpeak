import Foundation

public enum SpeechSynthesisError: Error, Sendable, Equatable {
    case voiceUnavailable
    case cancelled
}

public protocol SpeechSynthesizing: Sendable {
    func speak(text: String, languageTag: String) async throws
    func stopSpeaking()
    func resetEngine()
}

public protocol PhaseFilePlaying: Sendable {
    func play(url: URL) async throws
    func stop()
    func resetEngine()
}

public protocol DriveClocking: Sendable {
    func sleep(milliseconds: Int) async throws
}

public protocol DriveAssetResolving: Sendable {
    func fileURL(courseId: String, relativePath: String) -> URL?
}

public struct ContinuousClockSleeper: DriveClocking {
    public init() {}

    public func sleep(milliseconds: Int) async throws {
        let nanos = UInt64(max(milliseconds, 0)) * 1_000_000
        try await Task.sleep(nanoseconds: nanos)
    }
}

public struct EmptyAssetResolver: DriveAssetResolving {
    public init() {}

    public func fileURL(courseId: String, relativePath: String) -> URL? {
        _ = courseId
        _ = relativePath
        return nil
    }
}
