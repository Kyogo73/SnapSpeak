import SwiftUI

public struct ProgressRing: View {
    public var progress: Double
    public var lineWidth: CGFloat
    public var accessibilityLabel: LocalizedStringKey
    public var accessibilityValueText: String

    public init(
        progress: Double,
        lineWidth: CGFloat = 8,
        accessibilityLabel: LocalizedStringKey,
        accessibilityValueText: String
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValueText = accessibilityValueText
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Colors.secondaryFill.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    clamped >= 1 ? Colors.success : Colors.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if clamped >= 1 {
                Image(systemName: "checkmark")
                    .font(Typography.headline)
                    .foregroundStyle(Colors.success)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValueText)
    }

    private var clamped: Double {
        min(max(progress, 0), 1)
    }
}
