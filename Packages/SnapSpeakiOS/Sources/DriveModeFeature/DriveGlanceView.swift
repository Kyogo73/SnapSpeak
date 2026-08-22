import DesignSystem
import DriveKit
import SwiftUI

public struct DriveGlanceView: View {
    public var phaseKind: DrivePhaseKind
    public var paused: Bool
    public var completed: Int
    public var planned: Int
    public var onTogglePause: () -> Void
    public var onStop: () -> Void

    public init(
        phaseKind: DrivePhaseKind,
        paused: Bool,
        completed: Int,
        planned: Int,
        onTogglePause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.phaseKind = phaseKind
        self.paused = paused
        self.completed = completed
        self.planned = planned
        self.onTogglePause = onTogglePause
        self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("drive.glance.stop", action: onStop)
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                Text(LocalizedFormat.string("drive.glance.progress", completed, max(planned, 1)))
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Colors.secondaryFill)
            }
            Spacer()
            Text(stateKey)
                .font(.system(size: 64, weight: .bold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .accessibilityLabel(stateKey)
            Spacer()
            Button(action: onTogglePause) {
                Text(paused ? "drive.glance.resume" : "drive.glance.pause")
                    .font(Typography.title)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            .buttonStyle(.borderedProminent)
            .tint(Colors.accent)
            .accessibilityLabel(paused ? "drive.glance.resume" : "drive.glance.pause")
        }
        .padding()
    }

    private var stateKey: LocalizedStringKey {
        if paused { return "drive.glance.paused" }
        switch phaseKind {
        case .speakPause, .repeatPause:
            return "drive.glance.speak"
        case .revealL2:
            return "drive.glance.answer"
        case .promptL1, .shadowTrack, .trackGap, .itemGap,
             .sessionIntro, .sectionAnnounce, .sessionOutro:
            return "drive.glance.listening"
        }
    }
}
