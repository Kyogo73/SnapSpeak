import SwiftData

public enum SnapSpeakSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            DownloadedCourse.self,
            LessonAttempt.self,
            ReviewEvent.self,
            SRSCard.self,
            UserSettings.self,
            EntitlementCache.self,
        ]
    }
}
