import DesignSystem
import HabitKit
import SwiftUI

public struct OnboardingGoalView: View {
    @Binding public var selectedGoal: DailyGoal
    @Binding public var reminderEnabled: Bool
    @Binding public var reminderTime: DateComponents
    public var onStartLesson: () -> Void
    public var onSkip: () -> Void

    public init(
        selectedGoal: Binding<DailyGoal>,
        reminderEnabled: Binding<Bool>,
        reminderTime: Binding<DateComponents>,
        onStartLesson: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        _selectedGoal = selectedGoal
        _reminderEnabled = reminderEnabled
        _reminderTime = reminderTime
        self.onStartLesson = onStartLesson
        self.onSkip = onSkip
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("onboarding.goal.title")
                .font(Typography.title)
            Text("onboarding.goal.subtitle")
                .font(Typography.body)
                .foregroundStyle(Colors.secondaryFill)
            Picker("onboarding.goal.title", selection: $selectedGoal) {
                Text("onboarding.goal.preset_light").tag(DailyGoal.light)
                Text("onboarding.goal.preset_standard").tag(DailyGoal.standard)
                Text("onboarding.goal.preset_serious").tag(DailyGoal.serious)
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Toggle("onboarding.goal.reminder_toggle", isOn: $reminderEnabled)
                .frame(minHeight: 44)
            if reminderEnabled {
                DatePicker(
                    "onboarding.goal.reminder_time",
                    selection: reminderDateBinding,
                    displayedComponents: .hourAndMinute
                )
                .frame(minHeight: 44)
            }
            Spacer()
            PrimaryButton("onboarding.goal.start_lesson", action: onStartLesson)
            Button("onboarding.skip", action: onSkip)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = reminderTime.hour ?? 21
                components.minute = reminderTime.minute ?? 0
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderTime = DateComponents(hour: parts.hour, minute: parts.minute)
            }
        )
    }
}
