import ContentCore
import ContentKit
import DriveKit
import Foundation
import HabitKit
import LanguageKit
import SRSKit

enum DriveTestSupport {
    static func stored(_ course: Course, revision: Int = 1, directory: String = "/tmp/drive-tests") -> StoredCourse {
        StoredCourse(
            course: course,
            origin: .seed,
            directory: URL(fileURLWithPath: directory),
            revision: revision,
            releaseId: nil
        )
    }

    static func shadowingCourse(
        id: String = "course_a",
        lessons: [(String, [String])] = [("lesson_1", ["item_ok"])]
    ) throws -> Course {
        let pair = LanguagePair(
            sourceLanguage: try BCP47Language("ja"),
            targetLanguage: try BCP47Language("en")
        )
        let unitLessons: [LessonV1] = try lessons.map { lessonId, itemIds in
            let items: [ItemV1] = try itemIds.map { itemId in
                try ItemV1(
                    id: itemId,
                    kind: .shadowing,
                    audio: AudioRef(
                        relativePath: "audio/\(itemId).m4a",
                        durationMs: 1_000,
                        checksumSha256: String(repeating: "ab", count: 32)
                    ),
                    passage: PassageV1(
                        text: "Hello \(itemId)",
                        captionSegments: [CaptionSegment(startMs: 0, endMs: 400, text: "Hello")]
                    )
                )
            }
            return LessonV1(id: lessonId, mode: .shadowing, items: items)
        }
        return CourseV1(
            schemaVersion: 1,
            id: id,
            languagePair: pair,
            title: ["ja": "日常英会話"],
            units: [UnitV1(id: "unit_1", title: ["ja": "u"], lessons: unitLessons)]
        )
    }

    static func compositionCourse(
        id: String = "course_comp",
        lessonId: String = "lesson_c",
        itemId: String = "item_c",
        l1: String = "こんにちは",
        acceptable: [String] = ["Hello"]
    ) throws -> Course {
        let pair = LanguagePair(
            sourceLanguage: try BCP47Language("ja"),
            targetLanguage: try BCP47Language("en")
        )
        let item = try ItemV1(
            id: itemId,
            kind: .composition,
            audio: AudioRef(
                relativePath: "audio/\(itemId).m4a",
                durationMs: 800,
                checksumSha256: String(repeating: "cd", count: 32)
            ),
            sentencePair: SentencePairV1(l1: l1, acceptable: acceptable)
        )
        return CourseV1(
            schemaVersion: 1,
            id: id,
            languagePair: pair,
            title: ["ja": "瞬間英作文"],
            units: [
                UnitV1(
                    id: "unit_1",
                    title: ["ja": "u"],
                    lessons: [LessonV1(id: lessonId, mode: .composition, items: [item])]
                )
            ]
        )
    }

    static func due(
        courseId: String,
        itemId: String,
        skill: Skill = .shadowing,
        at: TimeInterval = 1
    ) -> DueCard {
        DueCard(
            cardKey: "k-\(courseId)-\(itemId)",
            courseId: courseId,
            itemId: itemId,
            skill: skill,
            dueAt: Date(timeIntervalSince1970: at),
            relearnGateAt: nil
        )
    }
}
