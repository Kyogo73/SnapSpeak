import Foundation

/// Semantic version used for manifest release selection (`minAppVersion` / `maxAppVersion`).
public struct AppVersion: Hashable, Sendable, Comparable, Codable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ string: String) throws {
        let core = string.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? string
        let parts = core.split(separator: ".").map(String.init)
        guard parts.count >= 1, parts.count <= 3, let major = Int(parts[0]) else {
            throw AppVersionError.invalid(string)
        }
        let minor = parts.count > 1 ? Int(parts[1]) : 0
        let patch = parts.count > 2 ? Int(parts[2]) : 0
        guard let minor, let patch else {
            throw AppVersionError.invalid(string)
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try AppVersion(try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

public enum AppVersionError: Error, Equatable, Sendable {
    case invalid(String)
}
