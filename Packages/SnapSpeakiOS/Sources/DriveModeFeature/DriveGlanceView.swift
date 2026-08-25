import DesignSystem
import DriveKit
import SwiftUI

public struct DriveGlanceView: View {
    public var phaseKind: DrivePhaseKind
    public var paused: Bool
    public var completed: Int
    public var planned: Int
    public var isEndless: Bool
    public var onTogglePause: () -> Void
    public var onStop: () -> Void

    public init(
        phaseKind: DrivePhaseKind,
        paused: Bool,
        completed: Int,
        planned: Int,
        isEndless: Bool = false,
        onTogglePause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self.phaseKind = phaseKind
        self.paused = paused
        self.completed = completed
        self.planned = planned
        self.isEndless = isEndless
        self.onTogglePause = onTogglePause
        self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("drive.glance.stop", action: onStop)
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                Text(progressText)
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Colors.secondaryFill)
            }
            Spacer()
            // ux-design §10.5.2: 走行中は超大型の状態語 1 情報。Dynamic Type 非追従は意図的。
            Text(stateKey)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .accessibilityLabel(stateKey)
            Spacer()
            Button(action: onTogglePause) {
                Text(paused ? "drive.glance.resume" : "drive.glance.pause")
                    .font(Typography.title)
                    .foregroundStyle(Colors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
            .buttonStyle(.borderedProminent)
            .tint(Colors.accent)
            .buttonBorderShape(.roundedRectangle(radius: 18))
            .accessibilityLabel(paused ? "drive.glance.resume" : "drive.glance.pause")
        }
        .padding()
    }

    private var progressText: String {
        if isEndless {
            return LocalizedFormat.string("drive.glance.progress_count", completed)
        }
        return LocalizedFormat.string("drive.glance.progress", completed, max(planned, 1))
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
