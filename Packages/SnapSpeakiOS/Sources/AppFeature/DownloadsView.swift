import ContentKit
import DesignSystem
import SwiftUI

public struct DownloadsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    public var courses: [StoredCourse]

    public init(courses: [StoredCourse]) {
        self.courses = courses
    }

    public var body: some View {
        List {
            if downloaded.isEmpty {
                Text("downloads.empty")
                    .font(Typography.body)
            }
            ForEach(downloaded, id: \.course.id) { stored in
                VStack(alignment: .leading, spacing: 8) {
                    Text(stored.course.id)
                        .font(Typography.headline)
                    Text("downloads.storage")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                    SecondaryButton("downloads.delete", systemImage: "trash") {
                        Task {
                            try? await dependencies.downloads.deleteCourse(courseId: stored.course.id)
                            try? await dependencies.persistence.deleteDownloadedCourse(
                                courseId: stored.course.id
                            )
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("downloads.title")
    }

    private var downloaded: [StoredCourse] {
        courses.filter { $0.origin == .downloaded }
    }
}
