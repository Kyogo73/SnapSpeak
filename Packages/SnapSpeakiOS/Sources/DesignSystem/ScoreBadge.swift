import SwiftUI

/// Score chip that never relies on color alone: symbol + percentage text.
public struct ScoreBadge: View {
    public var value: Double
    public var accessibilityLabel: LocalizedStringKey

    public init(value: Double, accessibilityLabel: LocalizedStringKey) {
        self.value = value
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .imageScale(.large)
                .accessibilityHidden(true)
            Text(percentText)
                .font(Typography.score)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(percentText)
    }

    private var clamped: Double {
        min(max(value, 0), 1)
    }

    private var percentText: String {
        let percent = Int((clamped * 100).rounded())
        return "\(percent)%"
    }

    private var symbolName: String {
        if clamped >= 0.8 { return "checkmark.circle.fill" }
        if clamped >= 0.4 { return "minus.circle.fill" }
        return "xmark.circle.fill"
    }

    private var tint: Color {
        if clamped >= 0.8 { return Colors.success }
        if clamped >= 0.4 { return Colors.warning }
        return Colors.danger
    }
}
