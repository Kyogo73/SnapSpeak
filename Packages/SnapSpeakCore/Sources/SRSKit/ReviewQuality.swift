import Foundation

/// SM-2 quality 0...5. Users never pick this; `SRSEngine` derives it.
public enum ReviewQuality: Int, Sendable, Codable, Equatable, CaseIterable {
    case blackout = 0
    case fail = 1
    case hard = 2
    case pass = 3
    case good = 4
    case easy = 5
}
