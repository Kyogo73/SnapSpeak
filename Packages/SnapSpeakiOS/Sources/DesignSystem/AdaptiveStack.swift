import SwiftUI

/// 最大 Dynamic Type では縦積み、通常サイズでは横並び。
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
        } else {
            HStack(alignment: .center, spacing: spacing) {
                content
            }
        }
    }
}
