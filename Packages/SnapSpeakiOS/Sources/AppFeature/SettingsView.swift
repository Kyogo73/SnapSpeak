import Analytics
import DesignSystem
import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Binding var path: [SettingsDestination]
    @State private var captionsEnabled = true
    @State private var installID = ""

    public init(path: Binding<[SettingsDestination]>) {
        _path = path
    }

    public var body: some View {
        Form {
            Toggle("settings.captions", isOn: $captionsEnabled)
                .frame(minHeight: 44)
            LabeledContent("settings.l1") {
                Text(dependencies.settings.sourceLanguage)
            }
            LabeledContent("settings.l2") {
                Text(dependencies.settings.targetLanguage)
            }
            LabeledContent("settings.install_id") {
                Text(installID)
                    .font(Typography.caption)
                    .textSelection(.enabled)
            }
            Button("settings.reset_install_id") {
                installID = InstallID.reset().uuidString
            }
            .frame(minHeight: 44)
            Button("settings.privacy") {
                path.append(.privacy)
            }
            .frame(minHeight: 44)
            Button("settings.downloads") {
                path.append(.downloads)
            }
            .frame(minHeight: 44)
        }
        .navigationTitle("settings.title")
        .task {
            installID = InstallID.current().uuidString
            if let loaded = try? await dependencies.persistence.loadOrCreateSettings() {
                captionsEnabled = loaded.captionsEnabled
            }
        }
        .onChange(of: captionsEnabled) { _, enabled in
            Task {
                var dto = dependencies.settings
                dto.captionsEnabled = enabled
                _ = try? await dependencies.persistence.saveSettings(dto)
            }
        }
    }
}
