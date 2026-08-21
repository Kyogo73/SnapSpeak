import ContentCore
import Foundation
import SRSKit

public enum SkillMapping: Sendable {
    public static func skill(for kind: ItemKind) -> Skill {
        switch kind {
        case .shadowing: return .shadowing
        case .composition: return .composition
        }
    }
}
