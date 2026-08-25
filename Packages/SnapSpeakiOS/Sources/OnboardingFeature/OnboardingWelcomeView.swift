import DesignSystem
import SwiftUI

public struct OnboardingWelcomeView: View {
    public var onStart: () -> Void
    public var onSkip: () -> Void

    public init(onStart: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onStart = onStart
        self.onSkip = onSkip
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 56))
                .foregroundStyle(Colors.accent)
                .accessibilityHidden(true)
            Text("onboarding.welcome.title")
                .font(Typography.title)
                .multilineTextAlignment(.center)
            Text("onboarding.welcome.subtitle")
                .font(Typography.body)
                .foregroundStyle(Colors.secondaryFill)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                Label("onboarding.welcome.point_shadowing", systemImage: "ear")
                Label("onboarding.welcome.point_composition", systemImage: "text.bubble")
            }
            .font(Typography.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            PrimaryButton("onboarding.welcome.start", action: onStart)
            Button("onboarding.skip", action: onSkip)
                .frame(minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .snapspeakCanvas()
    }
}
