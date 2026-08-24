import ContentCore
import ContentKit
import DesignSystem
import SwiftUI

public struct CatalogView: View {
    @Binding var path: [LessonCoordinate]
    public var courses: [StoredCourse]
    public var entitlement: EntitlementResolver
    public var onLockedItem: (LessonCoordinate) -> Void

    public init(
        path: Binding<[LessonCoordinate]>,
        courses: [StoredCourse],
        entitlement: EntitlementResolver,
        onLockedItem: @escaping (LessonCoordinate) -> Void
    ) {
        _path = path
        self.courses = courses
        self.entitlement = entitlement
        self.onLockedItem = onLockedItem
    }

    public var body: some View {
        List {
            if courses.isEmpty {
                Text("catalog.empty")
                    .font(Typography.body)
            }
            ForEach(courses, id: \.course.id) { stored in
                let courseTitle = LocalizedTitle.resolve(
                    stored.course.title,
                    requested: stored.course.languagePair.sourceLanguage,
                    sourceLanguage: stored.course.languagePair.sourceLanguage
                ) ?? stored.course.id
                Section(courseTitle) {
                    ForEach(stored.course.units, id: \.id) { unit in
                        let unitTitle = LocalizedTitle.resolve(
                            unit.title,
                            requested: stored.course.languagePair.sourceLanguage,
                            sourceLanguage: stored.course.languagePair.sourceLanguage
                        ) ?? unit.id
                        Text(unitTitle)
                            .font(Typography.headline)
                        ForEach(unit.lessons, id: \.id) { lesson in
                            ForEach(lesson.items, id: \.id) { item in
                                let coordinate = LessonCoordinate(
                                    courseId: stored.course.id,
                                    lessonId: lesson.id,
                                    itemId: item.id,
                                    mode: lesson.mode
                                )
                                let locked = ContentAccess.access(
                                    resolver: entitlement,
                                    courses: courses,
                                    coordinate: coordinate
                                ) == .locked
                                Button {
                                    if locked {
                                        onLockedItem(coordinate)
                                    } else {
                                        path.append(coordinate)
                                    }
                                } label: {
                                    HStack {
                                        Label(item.id, systemImage: icon(for: lesson.mode))
                                        if locked {
                                            Spacer()
                                            Image(systemName: "lock.fill")
                                            Text("catalog.locked")
                                                .font(Typography.caption)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                                .accessibilityLabel(
                                    locked
                                        ? LocalizedFormat.string("catalog.locked_item_a11y", item.id)
                                        : item.id
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("catalog.title")
    }

    private func icon(for mode: LessonMode) -> String {
        switch mode {
        case .shadowing: return "waveform"
        case .composition: return "text.bubble"
        }
    }
}
