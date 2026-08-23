import AudioEngine
import ContentCore
import ContentKit
import DriveKit
import Foundation
import HabitKit
import SRSKit

/// SessionPlan + StoredCourse → DriveItem。ReviewSessionViewModel.resolveEntries と同規則。
public enum DrivePlanResolver {
    public struct Lookup: Sendable, Equatable {
        public var lessonId: String
        public var contentRevision: Int
        public var languagePairKey: String
        public var courseTitle: String
        public var directory: URL

        public init(
            lessonId: String,
            contentRevision: Int,
            languagePairKey: String,
            courseTitle: String,
            directory: URL
        ) {
            self.lessonId = lessonId
            self.contentRevision = contentRevision
            self.languagePairKey = languagePairKey
            self.courseTitle = courseTitle
            self.directory = directory
        }
    }

    public struct Resolution: Sendable, Equatable {
        public var items: [DriveItem]
        public var lookups: [String: Lookup]
        public var skipped: Int

        public init(items: [DriveItem], lookups: [String: Lookup], skipped: Int) {
            self.items = items
            self.lookups = lookups
            self.skipped = skipped
        }
    }

    public static func resolve(plan: SessionPlan, courses: [StoredCourse]) -> Resolution {
        var items: [DriveItem] = []
        var lookups: [String: Lookup] = [:]
        var skipped = 0
        var seen = Set<String>()

        for card in plan.reviews {
            let key = itemKey(courseId: card.courseId, itemId: card.itemId)
            if seen.contains(key) { continue }
            if let mapped = mapItem(
                courseId: card.courseId,
                itemId: card.itemId,
                origin: .due,
                courses: courses
            ) {
                seen.insert(key)
                items.append(mapped.item)
                lookups[key] = mapped.lookup
            } else {
                skipped += 1
            }
        }

        if let lesson = plan.newLesson {
            for itemId in lesson.itemIds {
                let key = itemKey(courseId: lesson.courseId, itemId: itemId)
                if seen.contains(key) { continue }
                if let mapped = mapItem(
                    courseId: lesson.courseId,
                    itemId: itemId,
                    origin: .new,
                    courses: courses
                ) {
                    seen.insert(key)
                    items.append(mapped.item)
                    lookups[key] = mapped.lookup
                } else {
                    skipped += 1
                }
            }
        }
        return Resolution(items: items, lookups: lookups, skipped: skipped)
    }

    public static func repeatFillItems(courses: [StoredCourse], limit: Int = 40) -> Resolution {
        var items: [DriveItem] = []
        var lookups: [String: Lookup] = [:]
        var seen = Set<String>()
        let unique = CourseCatalog.uniquedActiveReleases(
            courses,
            id: { $0.course.id },
            revision: { $0.revision },
            releaseId: { $0.releaseId }
        )
        for stored in unique {
            for unit in stored.course.units {
                for lesson in unit.lessons {
                    for item in lesson.items {
                        guard items.count < limit else {
                            return Resolution(items: items, lookups: lookups, skipped: 0)
                        }
                        let key = itemKey(courseId: stored.course.id, itemId: item.id)
                        if seen.contains(key) { continue }
                        if let mapped = mapStoredItem(
                            stored: stored,
                            lessonId: lesson.id,
                            item: item,
                            origin: .repeatFill
                        ) {
                            seen.insert(key)
                            items.append(mapped.item)
                            lookups[key] = mapped.lookup
                        }
                    }
                }
            }
        }
        return Resolution(items: items, lookups: lookups, skipped: 0)
    }

    public static func itemKey(courseId: String, itemId: String) -> String {
        "\(courseId)|\(itemId)"
    }

    private static func mapItem(
        courseId: String,
        itemId: String,
        origin: DriveItem.Origin,
        courses: [StoredCourse]
    ) -> (item: DriveItem, lookup: Lookup)? {
        for stored in courses where stored.course.id == courseId {
            for unit in stored.course.units {
                for lesson in unit.lessons {
                    if let item = lesson.items.first(where: { $0.id == itemId }) {
                        return mapStoredItem(
                            stored: stored,
                            lessonId: lesson.id,
                            item: item,
                            origin: origin
                        )
                    }
                }
            }
        }
        return nil
    }

    private static func mapStoredItem(
        stored: StoredCourse,
        lessonId: String,
        item: ItemV1,
        origin: DriveItem.Origin
    ) -> (item: DriveItem, lookup: Lookup)? {
        let pair = stored.course.languagePair
        let skill = SkillMapping.skill(for: item.kind)
        let l1 = item.sentencePair?.l1
        let l2: String
        switch item.kind {
        case .composition:
            l2 = item.sentencePair?.acceptable.first ?? ""
        case .shadowing:
            l2 = item.passage?.text ?? ""
        }
        let driveItem = DriveItem(
            courseId: stored.course.id,
            itemId: item.id,
            skill: skill,
            origin: origin,
            l1Text: l1,
            l2Text: l2,
            l1LanguageTag: pair.sourceLanguage.raw,
            l2LanguageTag: pair.targetLanguage.raw,
            audioRelativePath: item.audio?.relativePath,
            audioDurationMs: item.audio?.durationMs
        )
        let title = LocalizedTitle.resolve(
            stored.course.title,
            requested: pair.sourceLanguage,
            sourceLanguage: pair.sourceLanguage
        ) ?? stored.course.id
        let lookup = Lookup(
            lessonId: lessonId,
            contentRevision: stored.revision,
            languagePairKey: pair.pairKey,
            courseTitle: title,
            directory: stored.directory
        )
        return (driveItem, lookup)
    }
}

public struct CourseDirectoryResolver: DriveAssetResolving, Sendable {
    private let directories: [String: URL]

    public init(courses: [StoredCourse]) {
        var map: [String: URL] = [:]
        for stored in courses {
            map[stored.course.id] = stored.directory
        }
        directories = map
    }

    public func fileURL(courseId: String, relativePath: String) -> URL? {
        directories[courseId]?.appendingPathComponent(relativePath)
    }
}
