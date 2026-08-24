import ContentCore
import ContentKit
import DesignSystem
import SwiftUI

public struct DownloadsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    public var courses: [StoredCourse]
    @State private var pendingDelete: StoredCourse?

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
                DownloadCourseRow(stored: stored) {
                    pendingDelete = stored
                }
            }
        }
        .navigationTitle("downloads.title")
        .confirmationDialog(
            "downloads.delete_confirm_title",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("downloads.delete_confirm", role: .destructive) {
                guard let stored = pendingDelete else { return }
                Task { await delete(stored) }
            }
            Button("common.close", role: .cancel) {}
        } message: {
            Text("downloads.delete_confirm_message")
        }
    }

    private var downloaded: [StoredCourse] {
        courses.filter { $0.origin == .downloaded }
    }

    private func delete(_ stored: StoredCourse) async {
        try? await dependencies.downloads.deleteCourse(courseId: stored.course.id)
        try? await dependencies.persistence.deleteDownloadedCourse(courseId: stored.course.id)
    }
}

private struct DownloadCourseRow: View {
    let stored: StoredCourse
    let onDelete: () -> Void
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var sizeText = DownloadCourseRow.formattedSize(0)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(resolvedTitle)
                .font(Typography.headline)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("downloads.storage")
                Text(sizeText)
            }
            .font(Typography.caption)
            .foregroundStyle(Colors.secondaryFill)
            SecondaryButton("downloads.delete", systemImage: "trash", action: onDelete)
        }
        .padding(.vertical, 8)
        .task {
            let bytes = await dependencies.downloads.courseSizeOnDisk(courseId: stored.course.id)
            sizeText = Self.formattedSize(bytes)
        }
    }

    private var resolvedTitle: String {
        LocalizedTitle.resolve(
            stored.course.title,
            requested: stored.course.languagePair.sourceLanguage,
            sourceLanguage: stored.course.languagePair.sourceLanguage
        ) ?? stored.course.id
    }

    private static func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
