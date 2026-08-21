import Foundation

public protocol Tokenizer: Sendable {
    func tokenize(_ text: String, language: BCP47Language) -> [Token]
}

public struct Token: Equatable, Sendable {
    public var surface: String
    public var normalized: String
    public var startMs: Int?
    public var endMs: Int?

    public init(surface: String, normalized: String, startMs: Int? = nil, endMs: Int? = nil) {
        self.surface = surface
        self.normalized = normalized
        self.startMs = startMs
        self.endMs = endMs
    }
}
