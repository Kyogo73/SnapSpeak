import CompositionFeature
import Foundation
import HabitKit
import Persistence
import ScoringKit
import SRSKit

@MainActor
public final class DashboardViewModel: ObservableObject {
    public enum DashboardState: Equatable {
        case loading
        case ready(ProgressSummary)
        case empty
        case failed
    }

    @Published public private(set) var state: DashboardState = .loading

    private let persistence: PersistenceActor

    public init(persistence: PersistenceActor) {
        self.persistence = persistence
    }

    public func load(now: Date = Date()) async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.autoupdatingCurrent
        do {
            let activity = try await persistence.attemptActivityDates()
            if activity.isEmpty {
                state = .empty
                return
            }
            let windowSamples = try await persistence.attempts(from: Self.windowStart(now: now, calendar: calendar), to: .distantFuture)
                .compactMap(Self.sample(from:))
            let settings = try await persistence.loadOrCreateSettings()
            let summary = ProgressSummarizer.summarize(
                activity: activity,
                windowSamples: windowSamples,
                goalItemsPerDay: settings.dailyGoalItems,
                now: now,
                calendar: calendar
            )
            state = .ready(summary)
        } catch {
            state = .failed
        }
    }

    /// DTO → core サンプルの写像（hostless テスト対象）。
    /// 未知の `skill`（現状到達不能）は `nil` を返して集計から除外する。
    /// デコード失敗時は nil メトリクスのままサンプルを返す（完了数には入る）。
    public static func sample(from dto: LessonAttemptDTO) -> ProgressSampleItem? {
        switch dto.skill {
        case "shadowing":
            let rate = (try? JSONDecoder().decode(ShadowingScore.self, from: dto.payloadJSON))?.scriptMatchRate
            return ProgressSampleItem(createdAt: dto.createdAt, mode: .shadowing, scriptMatchRate: rate)
        case "composition":
            return ProgressSampleItem(
                createdAt: dto.createdAt,
                mode: .composition,
                passed: compositionPassed(from: dto.payloadJSON)
            )
        default:
            return nil
        }
    }

    /// 今学習日開始の 30 日前（平均の窓。hostless テスト対象）。
    public static func windowStart(now: Date, calendar: Calendar) -> Date {
        let todayStart = StudyDay.studyDay(of: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: -30, to: todayStart) ?? todayStart
    }

    private static func compositionPassed(from payload: Data) -> Bool? {
        guard let decoded = try? JSONDecoder().decode(CompositionAttemptPayload.self, from: payload) else {
            return nil
        }
        switch decoded.result {
        case "pass":
            return true
        case "fail":
            return false
        default:
            return nil
        }
    }
}
