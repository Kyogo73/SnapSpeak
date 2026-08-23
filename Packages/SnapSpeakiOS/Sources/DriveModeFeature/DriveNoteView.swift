import DesignSystem
import SwiftUI

public struct DriveNoteView: View {
    public var note: DriveSessionViewModel.DriveNote
    public var onReplay: (DriveSessionViewModel.DriveNoteRow) -> Void
    public var onOpenLesson: (DriveSessionViewModel.DriveNoteRow) -> Void
    public var onClose: () -> Void

    public init(
        note: DriveSessionViewModel.DriveNote,
        onReplay: @escaping (DriveSessionViewModel.DriveNoteRow) -> Void,
        onOpenLesson: @escaping (DriveSessionViewModel.DriveNoteRow) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.note = note
        self.onReplay = onReplay
        self.onOpenLesson = onOpenLesson
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("drive.note.title")
                    .font(Typography.title)
                Text(LocalizedFormat.string("drive.note.summary", note.completedCount))
                    .font(Typography.headline)
                Text(
                    LocalizedFormat.string(
                        "drive.note.goal_progress",
                        note.goalCompletedBefore,
                        note.goalCompletedAfter,
                        note.goalItems
                    )
                )
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
                Text("drive.note.review_hint")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
                if note.missingCount > 0 {
                    Text("drive.note.missing")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.warning)
                }
                ForEach(note.rows) { row in
                    rowCard(row)
                }
                SecondaryButton("drive.note.open_lesson") {
                    if let first = note.rows.first { onOpenLesson(first) }
                }
                SecondaryButton("drive.note.close", action: onClose)
            }
            .padding()
        }
    }

    private func rowCard(_ row: DriveSessionViewModel.DriveNoteRow) -> some View {
        CardContainer {
            if let l1 = row.l1Text, !l1.isEmpty {
                Text(l1)
                    .font(Typography.body)
            }
            Text(row.l2Text)
                .font(Typography.headline)
            if row.passCount > 1 {
                Text(LocalizedFormat.string("drive.note.repeat_count", row.passCount))
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
            }
            SecondaryButton("drive.note.replay") {
                onReplay(row)
            }
        }
    }
}
