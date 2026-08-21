import Foundation
import ContentCore
import LanguageKit
import Testing

@Test func decodeGoldenManifest() throws {
    let data = try FixtureLoader.data("manifest_golden")
    let manifest = try Manifest.decode(from: data)
    #expect(manifest.manifestSchemaVersion == 1)
    #expect(manifest.courses.count == 1)
    #expect(manifest.courses[0].id == "course_travel_ja_en")
    #expect(manifest.courses[0].releases[0].revision == 1)
    #expect(manifest.courses[0].releases[0].maxAppVersion == nil)
}

@Test func releaseSelectorPicksHighestEligibleRevision() throws {
    let pair = LanguagePair(
        sourceLanguage: try BCP47Language("ja"),
        targetLanguage: try BCP47Language("en")
    )
    let course = ManifestCourse(
        id: "c",
        languagePair: pair,
        releases: [
            CourseRelease(
                releaseId: "r1",
                revision: 1,
                schemaVersion: 1,
                minAppVersion: try AppVersion("1.0.0"),
                maxAppVersion: try AppVersion("1.4.0"),
                contentUrl: "https://example.com/r1",
                bytes: 1,
                checksumSha256: "aa",
                inheritSRS: true
            ),
            CourseRelease(
                releaseId: "r2",
                revision: 2,
                schemaVersion: 1,
                minAppVersion: try AppVersion("1.0.0"),
                maxAppVersion: nil,
                contentUrl: "https://example.com/r2",
                bytes: 1,
                checksumSha256: "bb",
                inheritSRS: true
            ),
            CourseRelease(
                releaseId: "r3",
                revision: 3,
                schemaVersion: 2,
                minAppVersion: try AppVersion("1.0.0"),
                maxAppVersion: nil,
                contentUrl: "https://example.com/r3",
                bytes: 1,
                checksumSha256: "cc",
                inheritSRS: false
            ),
        ]
    )

    let selected = ReleaseSelector.select(course: course, appVersion: try AppVersion("1.2.0"))
    #expect(selected?.releaseId == "r2")

    let tooOld = ReleaseSelector.select(course: course, appVersion: try AppVersion("0.9.0"))
    #expect(tooOld == nil)

    let onlyV1 = ReleaseSelector.select(
        course: course,
        appVersion: try AppVersion("1.5.0"),
        knownSchemas: [1]
    )
    #expect(onlyV1?.revision == 2)

    let unknownOnly = ManifestCourse(
        id: "c2",
        languagePair: pair,
        releases: [
            CourseRelease(
                releaseId: "future",
                revision: 9,
                schemaVersion: 9,
                minAppVersion: try AppVersion("1.0.0"),
                maxAppVersion: nil,
                contentUrl: "https://example.com/x",
                bytes: 1,
                checksumSha256: "dd",
                inheritSRS: false
            ),
        ]
    )
    #expect(ReleaseSelector.select(course: unknownOnly, appVersion: try AppVersion("1.0.0")) == nil)
}

@Test func maxAppVersionIsExclusive() throws {
    let pair = LanguagePair(
        sourceLanguage: try BCP47Language("ja"),
        targetLanguage: try BCP47Language("en")
    )
    let course = ManifestCourse(
        id: "c",
        languagePair: pair,
        releases: [
            CourseRelease(
                releaseId: "capped",
                revision: 1,
                schemaVersion: 1,
                minAppVersion: try AppVersion("1.0.0"),
                maxAppVersion: try AppVersion("1.4.0"),
                contentUrl: "https://example.com/r1",
                bytes: 1,
                checksumSha256: "aa",
                inheritSRS: true
            ),
        ]
    )
    #expect(ReleaseSelector.select(course: course, appVersion: try AppVersion("1.3.9"))?.releaseId == "capped")
    #expect(ReleaseSelector.select(course: course, appVersion: try AppVersion("1.4.0")) == nil)
}
