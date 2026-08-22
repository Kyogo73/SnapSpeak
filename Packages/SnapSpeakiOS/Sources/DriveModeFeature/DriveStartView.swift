import DesignSystem
import DriveKit
import SwiftUI

public struct DriveStartView: View {
    public var dueCount: Int
    public var newCount: Int
    public var isRepeatFill: Bool
    public var loadFailed: Bool
    @Binding public var length: DriveScriptSettings.SessionLength
    public var onStart: () -> Void
    public var onRetry: () -> Void
    public var onClose: () -> Void

    public init(
        dueCount: Int,
        newCount: Int,
        isRepeatFill: Bool,
        loadFailed: Bool,
        length: Binding<DriveScriptSettings.SessionLength>,
        onStart: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.dueCount = dueCount
        self.newCount = newCount
        self.isRepeatFill = isRepeatFill
        self.loadFailed = loadFailed
        _length = length
        self.onStart = onStart
        self.onRetry = onRetry
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(minWidth: 44, minHeight: 44)
                }
                Spacer()
                Text("drive.start.title")
                    .font(Typography.headline)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            if loadFailed {
                Text("home.today.load_failed")
                    .font(Typography.body)
                SecondaryButton("home.today.retry", action: onRetry)
            } else {
                planBlock
                lengthPicker
                Button(action: onStart) {
                    Label("drive.start.start", systemImage: "play.fill")
                        .font(Typography.title)
                        .frame(maxWidth: .infinity, minHeight: 88)
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.accent)
                .accessibilityLabel("drive.start.start")
                Text("drive.start.safety_note")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var planBlock: some View {
        if isRepeatFill {
            Text("drive.start.plan_repeat_fill")
                .font(Typography.body)
        } else {
            Text(LocalizedFormat.string("drive.start.plan_summary", dueCount, newCount))
                .font(Typography.body)
        }
    }

    private var lengthPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settings.drive_length")
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
            HStack(spacing: 8) {
                lengthChip(.minutes5, titleKey: "drive.start.length_5")
                lengthChip(.minutes10, titleKey: "drive.start.length_10")
                lengthChip(.minutes20, titleKey: "drive.start.length_20")
                lengthChip(.endless, titleKey: "drive.start.length_endless")
            }
        }
    }

    private func lengthChip(
        _ value: DriveScriptSettings.SessionLength,
        titleKey: LocalizedStringKey
    ) -> some View {
        Button {
            length = value
        } label: {
            Text(titleKey)
                .font(Typography.callout)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(length == value ? Colors.accent : Colors.secondaryFill)
    }
}
