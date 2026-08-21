import Foundation
import ContentCore
import LanguageKit
import Testing

private func makeCourse(
    itemId: String,
    durationMs: Int,
    captions: [CaptionSegment],
    duplicate: Bool = false
) throws -> CourseV1 {
    let item = try ItemV1(
        id: itemId,
        kind: .shadowing,
        audio: AudioRef(relativePath: "audio/x.m4a", durationMs: durationMs, checksumSha256: "00"),
        passage: PassageV1(text: "Hi", captionSegments: captions)
    )
    var items = [item]
    if duplicate {
        items.append(item)
    }
    return CourseV1(
        schemaVersion: 1,
        id: "c",
        languagePair: LanguagePair(
            sourceLanguage: try BCP47Language("ja"),
            targetLanguage: try BCP47Language("en")
        ),
        title: ["en": "t"],
        units: [
            UnitV1(
                id: "u",
                title: ["en": "u"],
                lessons: [LessonV1(id: "l", mode: .shadowing, items: items)]
            ),
        ]
    )
}

@Test func nonMonotonicCaptionsAreErrors() throws {
    let course = try makeCourse(
        itemId: "i1",
        durationMs: 1000,
        captions: [
            CaptionSegment(startMs: 0, endMs: 500, text: "a"),
            CaptionSegment(startMs: 400, endMs: 800, text: "b"),
        ]
    )
    let errors = ContentValidator().validate(course)
    #expect(errors.contains(.captionNotMonotonic(itemId: "i1")))
}

@Test func durationOver50SecondsIsError() throws {
    let course = try makeCourse(
        itemId: "i1",
        durationMs: 51_000,
        captions: [CaptionSegment(startMs: 0, endMs: 1000, text: "a")]
    )
    let errors = ContentValidator().validate(course)
    #expect(errors.contains(.durationTooLong(itemId: "i1", durationMs: 51_000)))
}

@Test func duplicateItemIDsAreErrors() throws {
    let course = try makeCourse(
        itemId: "dup",
        durationMs: 1000,
        captions: [CaptionSegment(startMs: 0, endMs: 1000, text: "a")],
        duplicate: true
    )
    let errors = ContentValidator().validate(course)
    #expect(errors.contains(.duplicateItemID("dup")))
}

@Test func goldenSeedPassesValidation() throws {
    let data = try FixtureLoader.data("course_v1_golden")
    let course = try ContentDecoder.decodeCourse(from: data)
    #expect(ContentValidator().validate(course).isEmpty)
}
