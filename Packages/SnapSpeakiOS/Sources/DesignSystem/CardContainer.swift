import SwiftUI

public struct CardContainer<Content: View>: View {
    private let content: Content
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Colors.cardFill, in: shape)
            .overlay(shape.stroke(Colors.cardStroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
    }
}
