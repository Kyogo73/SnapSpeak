import Foundation
import LanguageKit

public enum Skill: String, Sendable, Codable, Equatable, CaseIterable {
    case shadowing
    case composition
}

public struct CardKey: Hashable, Sendable, Codable, Equatable, CustomStringConvertible {
    public var pairKey: String
    public var courseId: String
    public var itemId: String
    public var skill: Skill

    public init(pairKey: String, courseId: String, itemId: String, skill: Skill) {
        self.pairKey = pairKey
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
    }

    public init(pair: LanguagePair, courseId: String, itemId: String, skill: Skill) {
        self.init(pairKey: pair.pairKey, courseId: courseId, itemId: itemId, skill: skill)
    }

    public var raw: String {
        "\(pairKey):\(courseId):\(itemId):\(skill.rawValue)"
    }

    public var description: String { raw }
}
