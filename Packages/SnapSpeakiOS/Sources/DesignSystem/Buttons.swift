import SwiftUI

public struct PrimaryButton: View {
    public var titleKey: LocalizedStringKey
    public var systemImage: String?
    public var action: () -> Void

    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(titleKey)
                    .font(Typography.headline)
            }
            .foregroundStyle(Colors.onAccent)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(Colors.accent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }
}

public struct SecondaryButton: View {
    public var titleKey: LocalizedStringKey
    public var systemImage: String?
    public var action: () -> Void

    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(titleKey)
                    .font(Typography.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(Colors.accent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }
}
