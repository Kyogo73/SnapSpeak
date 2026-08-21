import DesignSystem
import SwiftUI
import UIKit

public struct PrivacyView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("privacy.title")
                    .font(Typography.title)
                Text("privacy.body")
                    .font(Typography.body)
                Label("privacy.mic", systemImage: "mic.fill")
                    .font(Typography.body)
                    .frame(minHeight: 44)
                Label("privacy.speech", systemImage: "waveform")
                    .font(Typography.body)
                    .frame(minHeight: 44)
                Label("privacy.retention", systemImage: "calendar")
                    .font(Typography.body)
                    .frame(minHeight: 44)
                Text("privacy.required_reason_note")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
                if let url = URL(string: "https://snapspeak.app/privacy") {
                    Link("privacy.policy", destination: url)
                        .frame(minHeight: 44)
                }
                PrimaryButton("privacy.open_settings", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("privacy.title")
    }
}
