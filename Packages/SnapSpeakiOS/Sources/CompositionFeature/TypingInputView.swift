import DesignSystem
import SwiftUI

public struct TypingInputView: View {
    @Binding var text: String
    public var onSubmit: () -> Void

    public init(text: Binding<String>, onSubmit: @escaping () -> Void) {
        _text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("composition.type", text: $text, axis: .vertical)
                .font(Typography.body)
                .lineLimit(3...6)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
            PrimaryButton("composition.submit", systemImage: "checkmark", action: onSubmit)
        }
    }
}
