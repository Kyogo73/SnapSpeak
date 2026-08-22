import Analytics
import DesignSystem
import HabitKit
import NotificationsKit
import Persistence
import SwiftUI
import UIKit

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Binding var path: [SettingsDestination]
    public var today: TodayViewModel?
    @State private var captionsEnabled = true
    @State private var installID = ""
    @State private var dailyGoalItems = DailyGoal.standard.itemsPerDay
    @State private var reminderEnabled = false
    @State private var reminderDate = SettingsView.defaultReminderDate
    @State private var reminderDenied = false
    @State private var didLoad = false
    @State private var saveFailed = false
    @Environment(\.scenePhase) private var scenePhase

    public init(path: Binding<[SettingsDestination]>, today: TodayViewModel? = nil) {
        _path = path
        self.today = today
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
            Section("settings.section_habit") {
                Picker("settings.goal", selection: $dailyGoalItems) {
                    Text("onboarding.goal.preset_light").tag(DailyGoal.light.itemsPerDay)
                    Text("onboarding.goal.preset_standard").tag(DailyGoal.standard.itemsPerDay)
                    Text("onboarding.goal.preset_serious").tag(DailyGoal.serious.itemsPerDay)
                }
                .frame(minHeight: 44)
                Toggle("settings.reminder", isOn: $reminderEnabled)
                    .frame(minHeight: 44)
                if reminderEnabled {
                    DatePicker(
                        "settings.reminder_time",
                        selection: $reminderDate,
                        displayedComponents: .hourAndMinute
                    )
                    .frame(minHeight: 44)
                }
                if saveFailed {
                    Text("settings.save_failed")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.danger)
                }
                if reminderDenied {
                    Text("settings.reminder_denied")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                    Button("settings.open_notification_settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .frame(minHeight: 44)
                }
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
            await loadFromStore()
            didLoad = true
        }
        .onChange(of: captionsEnabled) { _, _ in
            guard didLoad else { return }
            Task { await persistHabitSettings() }
        }
        .onChange(of: dailyGoalItems) { _, _ in
            guard didLoad else { return }
            Task { await persistHabitSettings() }
        }
        .onChange(of: reminderEnabled) { _, enabled in
            guard didLoad else { return }
            Task { await handleReminderToggle(enabled) }
        }
        .onChange(of: reminderDate) { _, _ in
            guard didLoad else { return }
            Task { await persistHabitSettings() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await reloadAuthorization() }
            }
        }
    }

    private func loadFromStore() async {
        guard let loaded = try? await dependencies.persistence.loadOrCreateSettings() else { return }
        captionsEnabled = loaded.captionsEnabled
        dailyGoalItems = loaded.dailyGoalItems
        reminderEnabled = loaded.reminderEnabled
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = loaded.reminderHour ?? 21
        components.minute = loaded.reminderMinute
        reminderDate = Calendar.current.date(from: components) ?? Self.defaultReminderDate
        await reloadAuthorization()
    }

    private func reloadAuthorization() async {
        let auth = await dependencies.reminderScheduler.authorization()
        reminderDenied = auth == .denied
    }

    private func handleReminderToggle(_ enabled: Bool) async {
        if enabled {
            let granted = await dependencies.reminderScheduler.requestAuthorizationIfNeeded()
            let auth = await dependencies.reminderScheduler.authorization()
            reminderDenied = auth == .denied
            if !granted {
                reminderEnabled = false
            }
        }
        await persistHabitSettings()
    }

    private func persistHabitSettings() async {
        var dto = (try? await dependencies.persistence.loadOrCreateSettings()) ?? dependencies.settings
        dto.captionsEnabled = captionsEnabled
        dto.dailyGoalItems = dailyGoalItems
        dto.reminderEnabled = reminderEnabled && !reminderDenied
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        dto.reminderHour = parts.hour
        dto.reminderMinute = parts.minute ?? 0
        do {
            _ = try await dependencies.persistence.saveSettings(dto)
            saveFailed = false
            await today?.refresh()
        } catch {
            saveFailed = true
        }
    }

    private static var defaultReminderDate: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 21
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
