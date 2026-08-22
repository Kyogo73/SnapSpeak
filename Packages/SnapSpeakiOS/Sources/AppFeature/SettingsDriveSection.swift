import DriveKit
import DriveModeFeature
import SwiftUI

struct SettingsDriveSection: View {
    @Binding var length: DriveScriptSettings.SessionLength
    @Binding var pause: DrivePausePreset
    @Binding var repeats: Int

    var body: some View {
        Section("settings.section_drive") {
            Picker("settings.drive_length", selection: $length) {
                Text("drive.start.length_5").tag(DriveScriptSettings.SessionLength.minutes5)
                Text("drive.start.length_10").tag(DriveScriptSettings.SessionLength.minutes10)
                Text("drive.start.length_20").tag(DriveScriptSettings.SessionLength.minutes20)
                Text("drive.start.length_endless").tag(DriveScriptSettings.SessionLength.endless)
            }
            .frame(minHeight: 44)
            Picker("settings.drive_pause", selection: $pause) {
                Text("settings.drive_pause_short").tag(DrivePausePreset.short)
                Text("settings.drive_pause_standard").tag(DrivePausePreset.standard)
                Text("settings.drive_pause_long").tag(DrivePausePreset.long)
            }
            .frame(minHeight: 44)
            Picker("settings.drive_repeats", selection: $repeats) {
                Text(verbatim: "1").tag(1)
                Text(verbatim: "2").tag(2)
                Text(verbatim: "3").tag(3)
            }
            .frame(minHeight: 44)
        }
    }
}
