import SwiftUI

public struct StreakBadge: View {
    public var days: Int
    public var isAtRisk: Bool
    public var accessibilityLabel: LocalizedStringKey
    public var accessibilityHint: LocalizedStringKey?

    public init(
        days: Int,
        isAtRisk: Bool,
        accessibilityLabel: LocalizedStringKey,
        accessibilityHint: LocalizedStringKey? = nil
    ) {
        self.days = days
        self.isAtRisk = isAtRisk
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isAtRisk ? "flame" : "flame.fill")
                .imageScale(.large)
                .foregroundStyle(isAtRisk ? Colors.warning : Colors.accent)
                .accessibilityHidden(true)
            Text("\(days)")
                .font(Typography.headline)
                .monospacedDigit()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? LocalizedStringKey(""))
    }
}
