import ContentCore
import ContentKit
import DesignSystem
import SwiftUI

public struct HomeView: View {
    @Binding var path: [LessonCoordinate]
    public var courses: [StoredCourse]

    public init(path: Binding<[LessonCoordinate]>, courses: [StoredCourse]) {
        _path = path
        self.courses = courses
    }

    public var body: some View {
        List {
            Section {
                Text("home.title")
                    .font(Typography.title)
                    .listRowSeparator(.hidden)
            }
            if let lesson = firstLesson {
                Button {
                    path.append(lesson)
                } label: {
                    Label("home.continue", systemImage: "play.circle.fill")
                        .frame(minHeight: 44)
                }
            }
            ForEach(courses, id: \.course.id) { stored in
                let title = LocalizedTitle.resolve(
                    stored.course.title,
                    requested: stored.course.languagePair.sourceLanguage,
                    sourceLanguage: stored.course.languagePair.sourceLanguage
                ) ?? stored.course.id
                Text(title)
                    .font(Typography.headline)
            }
        }
        .navigationTitle("tab.home")
    }

    private var firstLesson: LessonCoordinate? {
        guard let stored = courses.first,
              let lesson = stored.course.units.first?.lessons.first,
              let item = lesson.items.first
        else { return nil }
        return LessonCoordinate(
            courseId: stored.course.id,
            lessonId: lesson.id,
            itemId: item.id,
            mode: lesson.mode
        )
    }
}
