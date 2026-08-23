import Foundation
import SRSKit

/// スクリプト生成の入力 1 件（SessionPlan + StoredCourse からの写像）。
public struct DriveItem: Sendable, Equatable {
    public enum Origin: String, Sendable, Equatable {
        case due
        case new
        case repeatFill
    }

    public var courseId: String
    public var itemId: String
    public var skill: Skill
    public var origin: Origin
    /// composition の出題。composition では必須。欠落は builder が除外する。
    public var l1Text: String?
    /// composition: acceptable 先頭 / shadowing: passage.text
    public var l2Text: String
    public var l1LanguageTag: String
    public var l2LanguageTag: String
    /// お手本音声（コースディレクトリ相対）。
    public var audioRelativePath: String?
    /// コンテンツ JSON の durationMs。
    public var audioDurationMs: Int?

    public init(
        courseId: String,
        itemId: String,
        skill: Skill,
        origin: Origin,
        l1Text: String?,
        l2Text: String,
        l1LanguageTag: String,
        l2LanguageTag: String,
        audioRelativePath: String?,
        audioDurationMs: Int?
    ) {
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.origin = origin
        self.l1Text = l1Text
        self.l2Text = l2Text
        self.l1LanguageTag = l1LanguageTag
        self.l2LanguageTag = l2LanguageTag
        self.audioRelativePath = audioRelativePath
        self.audioDurationMs = audioDurationMs
    }
}

/// Item の 1 周（pass）を識別する参照。
public struct DriveItemRef: Sendable, Equatable, Hashable {
    public var courseId: String
    public var itemId: String
    public var skill: Skill
    /// 0 始まり。反復充填で増える。
    public var passIndex: Int

    public init(courseId: String, itemId: String, skill: Skill, passIndex: Int) {
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.passIndex = passIndex
    }
}
