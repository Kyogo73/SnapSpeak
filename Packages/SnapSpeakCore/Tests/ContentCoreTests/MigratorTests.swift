import Foundation
import ContentCore
import Testing

@Test func v1MigrationIsIdentity() throws {
    let data = try FixtureLoader.data("course_v1_golden")
    let decoded = try ContentDecoder.decodeCourse(from: data)
    let migrated = CourseMigrator.migrate(decoded)
    #expect(migrated == decoded)
}
