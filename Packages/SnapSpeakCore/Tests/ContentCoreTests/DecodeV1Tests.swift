import Foundation
import ContentCore
import Testing

enum FixtureLoader {
    static func data(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }
}

@Test func decodeGoldenCourse() throws {
    let data = try FixtureLoader.data("course_v1_golden")
    let course = try ContentDecoder.decodeCourse(from: data)
    #expect(course.schemaVersion == 1)
    #expect(course.id == "course_daily_ja_en")
    #expect(course.languagePair.pairKey == "ja>en")
    #expect(course.title["en"] == "Daily English")
    #expect(course.units.count == 1)
    #expect(course.units[0].lessons.count == 2)
    let shadowing = course.units[0].lessons[0]
    #expect(shadowing.mode == .shadowing)
    #expect(shadowing.items.count == 3)
    #expect(shadowing.items[0].kind == .shadowing)
    #expect(shadowing.items[0].passage != nil)
    #expect(shadowing.items[0].passage?.wordTimings?.isEmpty == false)
    let composition = course.units[0].lessons[1]
    #expect(composition.mode == .composition)
    #expect(composition.items.count == 8)
    #expect(composition.items[0].sentencePair?.acceptable.count ?? 0 >= 2)
}

@Test func unknownOptionalFieldsAreIgnored() throws {
    var json = try FixtureLoader.data("course_v1_golden")
    var object = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
    object["futureOptional"] = "ignored"
    json = try JSONSerialization.data(withJSONObject: object)
    let course = try ContentDecoder.decodeCourse(from: json)
    #expect(course.id == "course_daily_ja_en")
}
