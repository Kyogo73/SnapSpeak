import DesignSystem
import SwiftUI

/// 完走 / 停止直後の安全な 1 情報画面。学習テキストは出さない（D2）。
public struct DriveCompletedView: View {
    public var completedCount: Int
    public var onOpenNote: () -> Void
    public var onClose: () -> Void

    public init(completedCount: Int, onOpenNote: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.completedCount = completedCount
        self.onOpenNote = onOpenNote
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("drive.note.close", action: onClose)
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
            }
            Spacer()
            Text("drive.glance.done")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .accessibilityLabel("drive.glance.done")
            Text(LocalizedFormat.string("drive.note.summary", completedCount))
                .font(Typography.headline)
                .monospacedDigit()
            Spacer()
            Button(action: onOpenNote) {
                Text("drive.completed.open_note")
                    .font(Typography.title)
                    .foregroundStyle(Colors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            .buttonStyle(.borderedProminent)
            .tint(Colors.accent)
            .buttonBorderShape(.roundedRectangle(radius: 18))
            .accessibilityLabel("drive.completed.open_note")
        }
        .padding()
    }
}
