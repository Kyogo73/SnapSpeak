import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var captionsEnabled: Bool
    public var defaultRate: Float
    public var reminderHour: Int?
    public var fieldRevisionsJSON: Data
    public var deletedAt: Date?

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        captionsEnabled: Bool,
        defaultRate: Float,
        reminderHour: Int?,
        fieldRevisionsJSON: Data,
        deletedAt: Date?
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.captionsEnabled = captionsEnabled
        self.defaultRate = defaultRate
        self.reminderHour = reminderHour
        self.fieldRevisionsJSON = fieldRevisionsJSON
        self.deletedAt = deletedAt
    }
}
