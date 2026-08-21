import SwiftData

public enum SnapSpeakMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SnapSpeakSchemaV1.self]
    }

    public static var stages: [MigrationStage] { [] }
}
