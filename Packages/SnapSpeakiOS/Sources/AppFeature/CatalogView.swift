import ContentCore
import ContentKit
import DesignSystem
import SwiftUI

public struct CatalogView: View {
    @Binding var path: [LessonCoordinate]
    public var courses: [StoredCourse]

    public init(path: Binding<[LessonCoordinate]>, courses: [StoredCourse]) {
        _path = path
        self.courses = courses
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
                                Button {
                                    path.append(
                                        LessonCoordinate(
                                            courseId: stored.course.id,
                                            lessonId: lesson.id,
                                            itemId: item.id,
                                            mode: lesson.mode
                                        )
                                    )
                                } label: {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(itemHeadline(item))
                                                .font(Typography.headline)
                                                .multilineTextAlignment(.leading)
                                            Text(modeTitleKey(for: lesson.mode))
                                                .font(Typography.caption)
                                                .foregroundStyle(Colors.secondaryFill)
                                        }
                                    } icon: {
                                        Image(systemName: icon(for: lesson.mode))
                                    }
                                    .frame(minHeight: 44)
                                }
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

    private func modeTitleKey(for mode: LessonMode) -> LocalizedStringKey {
        switch mode {
        case .shadowing: return "shadowing.title"
        case .composition: return "composition.title"
        }
    }

    /// Labels use passage.text / sentencePair.l1. LessonV1 has no title.
    private func itemHeadline(_ item: ItemV1) -> String {
        if let text = item.passage?.text, !text.isEmpty {
            return truncatedPassage(text)
        }
        if let l1 = item.sentencePair?.l1, !l1.isEmpty {
            return l1
        }
        return item.id
    }

    private func truncatedPassage(_ text: String) -> String {
        guard text.count > 40 else { return text }
        return String(text.prefix(40)) + "…"
    }
}
