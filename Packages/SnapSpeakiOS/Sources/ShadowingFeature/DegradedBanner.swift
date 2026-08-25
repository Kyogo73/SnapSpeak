import DesignSystem
import SwiftUI

public struct DegradedBanner: View {
    public var titleKey: LocalizedStringKey
    public var systemImage: String

    public init(titleKey: LocalizedStringKey, systemImage: String = "exclamationmark.triangle.fill") {
        self.titleKey = titleKey
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Colors.warning)
                .accessibilityHidden(true)
            Text(titleKey)
                .font(Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(minHeight: 44)
        .background(Colors.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
