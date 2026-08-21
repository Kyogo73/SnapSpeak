import Foundation

public enum AlignmentOp: Sendable, Equatable {
    case equal(ref: Int, hyp: Int)
    case substitution(ref: Int, hyp: Int)
    case deletion(ref: Int)
    case insertion(hyp: Int)
}

public struct AlignedSpan: Codable, Sendable, Equatable {
    public var startRefIndex: Int
    public var endRefIndex: Int

    public init(startRefIndex: Int, endRefIndex: Int) {
        self.startRefIndex = startRefIndex
        self.endRefIndex = endRefIndex
    }
}
