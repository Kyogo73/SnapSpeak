import Charts
import DesignSystem
import HabitKit
import Persistence
import SwiftUI

public struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel

    public init(persistence: PersistenceActor) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(persistence: persistence))
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .empty:
                emptyState
            case .failed:
                failedState
            case let .ready(summary):
                readyContent(summary)
            }
        }
        .navigationTitle("dashboard.title")
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        ScrollView {
            CardContainer {
                Text("dashboard.empty")
                    .font(Typography.body)
            }
            .padding()
        }
    }

    private var failedState: some View {
        ScrollView {
            CardContainer {
                Text("dashboard.load_failed")
                    .font(Typography.body)
                SecondaryButton("dashboard.retry") {
                    Task { await viewModel.load() }
                }
            }
            .padding()
        }
    }

    private func readyContent(_ summary: ProgressSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                streakCard(summary)
                weekCard(summary)
                modesCard(summary)
                notesCard
            }
            .padding()
        }
    }

    private func streakCard(_ summary: ProgressSummary) -> some View {
        CardContainer {
            Text("dashboard.streak.title")
                .font(Typography.headline)
            StreakBadge(
                days: summary.streak.currentStreakDays,
                isAtRisk: summary.streak.isAtRisk,
                accessibilityLabel: LocalizedStringKey(
                    LocalizedFormat.string("streak.badge_label", summary.streak.currentStreakDays)
                ),
                accessibilityHint: summary.streak.isAtRisk ? "streak.at_risk" : nil
            )
            Text(LocalizedFormat.string("dashboard.streak.longest", summary.streak.longestStreakDays))
                .font(Typography.body)
            Text(LocalizedFormat.string("dashboard.streak.total", summary.streak.totalStudyDays))
                .font(Typography.body)
        }
    }

    private func weekCard(_ summary: ProgressSummary) -> some View {
        CardContainer {
            Text("dashboard.week.title")
                .font(Typography.headline)
            weekChart(summary)
                .frame(height: 180)
                .accessibilityLabel("dashboard.week.title")
            Text(LocalizedFormat.string("dashboard.week.total", summary.weekCompletedItems))
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
        }
    }

    private func weekChart(_ summary: ProgressSummary) -> some View {
        Chart(summary.dailyBars, id: \.dayStart) { bar in
            BarMark(
                x: .value(LocalizedStringKey("dashboard.chart.axis_day"), bar.dayStart, unit: .day),
                y: .value(LocalizedStringKey("dashboard.chart.axis_count"), bar.completedItems)
            )
            .foregroundStyle(bar.goalMet ? Colors.accent : Colors.secondaryFill)
            .annotation(position: .top) {
                Text(verbatim: "\(bar.completedItems)")
                    .font(Typography.caption)
                    .monospacedDigit()
                    .foregroundStyle(Colors.secondaryFill)
            }
            .accessibilityLabel(Text(verbatim: shortDayLabel(bar.dayStart)))
            .accessibilityValue(Text(verbatim: barValueLabel(bar)))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(verbatim: shortDayLabel(date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private func modesCard(_ summary: ProgressSummary) -> some View {
        CardContainer {
            Text("dashboard.modes.title")
                .font(Typography.headline)
            modeRow(
                titleKey: "dashboard.modes.shadowing",
                rate: summary.shadowingAverageMatchRate,
                sampleCount: summary.shadowingSampleCount
            )
            modeRow(
                titleKey: "dashboard.modes.composition",
                rate: summary.compositionPassRate,
                sampleCount: summary.compositionScoredCount
            )
        }
    }

    private func modeRow(titleKey: LocalizedStringKey, rate: Double?, sampleCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(Typography.headline)
            if let rate {
                Text(LocalizedFormat.string("dashboard.modes.rate_value", Int((rate * 100).rounded())))
                    .font(Typography.score)
                Text(LocalizedFormat.string("dashboard.modes.samples", sampleCount))
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
            } else {
                Text("dashboard.modes.no_data")
                    .font(Typography.body)
                    .foregroundStyle(Colors.secondaryFill)
            }
        }
    }

    private var notesCard: some View {
        CardContainer {
            Text("dashboard.metric_note")
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
            Text("dashboard.local_note")
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
        }
    }

    private func shortDayLabel(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().weekday(.abbreviated).locale(.autoupdatingCurrent))
    }

    private func barValueLabel(_ bar: DailyProgressBar) -> String {
        let count = LocalizedFormat.string("dashboard.bar.value_label", bar.completedItems)
        if bar.goalMet {
            return count + " " + LocalizedFormat.string("dashboard.bar.goal_met")
        }
        return count
    }
}
