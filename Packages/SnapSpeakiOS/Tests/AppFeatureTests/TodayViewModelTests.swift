import Analytics
import AppFeature
import Foundation
import HabitKit
import NotificationsKit
import Persistence
import ReviewFeature
import SRSKit
import Testing

@Suite("TodayViewModel")
@MainActor
struct TodayViewModelTests {
    @Test("遅い第 1 世代の refresh は後続結果を上書きしない")
    func staleRefreshDoesNotOverwriteNewerSnapshot() async throws {
        let planning = FakeTodayPlanning()
        await planning.configure(
            holdFirst: true,
            results: [
                .success(Self.snapshot(itemId: "slow")),
                .success(Self.snapshot(itemId: "fast")),
            ]
        )
        let viewModel = try makeViewModel(planning: planning)

        async let first: Void = viewModel.refresh()
        await planning.waitUntilFirstStarted()
        await viewModel.refresh()
        await planning.releaseFirst()
        await first

        #expect(viewModel.snapshot?.plan.reviews.map(\.itemId) == ["fast"])
        #expect(viewModel.state == .ready)
    }

    @Test("makeToday throw → state == failed")
    func makeTodayThrowSetsFailed() async throws {
        let planning = FakeTodayPlanning()
        await planning.configure(results: [.failure(FakePlanError.makeTodayFailed)])
        let viewModel = try makeViewModel(planning: planning)

        await viewModel.refresh()

        #expect(viewModel.state == .failed)
        #expect(viewModel.snapshot == nil)
    }

    @Test("regeneratePlanThenStart は failed のとき false（古い plan で開始しない）")
    func regeneratePlanThenStartIsFalseWhenFailed() async throws {
        let planning = FakeTodayPlanning()
        await planning.configure(results: [
            .success(Self.snapshot(itemId: "old")),
            .failure(FakePlanError.makeTodayFailed),
        ])
        let viewModel = try makeViewModel(planning: planning)

        await viewModel.refresh()
        #expect(viewModel.state == .ready)
        #expect(viewModel.snapshot?.plan.reviews.map(\.itemId) == ["old"])

        let started = await viewModel.regeneratePlanThenStart()
        #expect(started == false)
        #expect(viewModel.state == .failed)
    }

    private func makeViewModel(planning: FakeTodayPlanning) throws -> TodayViewModel {
        let container = try PersistenceActor.makeContainer(inMemory: true)
        let persistence = PersistenceActor(modelContainer: container)
        let analytics = NoopAnalytics()
        let scheduler = ReminderScheduler(
            center: FakeAppReminderCenter(),
            analytics: analytics
        )
        return TodayViewModel(
            persistence: persistence,
            todayPlanService: planning,
            scheduler: scheduler,
            analytics: analytics
        )
    }

    private static func snapshot(itemId: String) -> TodaySnapshot {
        let now = Date(timeIntervalSince1970: 1_777_000_000)
        let card = DueCard(
            cardKey: "ja>en:course_a:\(itemId):shadowing",
            courseId: "course_a",
            itemId: itemId,
            skill: .shadowing,
            dueAt: now,
            relearnGateAt: nil
        )
        return TodaySnapshot(
            streak: StreakSnapshot(
                currentStreakDays: 1,
                longestStreakDays: 1,
                totalStudyDays: 1,
                studiedToday: true,
                isAtRisk: false,
                isOnLastGraceDay: false
            ),
            goal: GoalProgress(completedItems: 0, goalItems: 10),
            plan: SessionPlan(reviews: [card], deferredDueCount: 0, newLesson: nil),
            hasCourses: true
        )
    }
}

actor FakeTodayPlanning: TodayPlanning {
    private var holdFirst = false
    private var results: [Result<TodaySnapshot, FakePlanError>] = []
    private var index = 0
    private var firstHasStarted = false
    private var firstStarted: CheckedContinuation<Void, Never>?
    private var firstHold: CheckedContinuation<Void, Never>?

    func configure(
        holdFirst: Bool = false,
        results: [Result<TodaySnapshot, FakePlanError>]
    ) {
        self.holdFirst = holdFirst
        self.results = results
        index = 0
        firstHasStarted = false
        firstStarted = nil
        firstHold = nil
    }

    func waitUntilFirstStarted() async {
        if firstHasStarted { return }
        await withCheckedContinuation { continuation in
            if firstHasStarted {
                continuation.resume()
            } else {
                firstStarted = continuation
            }
        }
    }

    func releaseFirst() {
        firstHold?.resume()
        firstHold = nil
    }

    func makeToday(
        now: Date,
        timeZone: TimeZone,
        goal: DailyGoal,
        policy: SessionPlanPolicy
    ) async throws -> TodaySnapshot {
        _ = now
        _ = timeZone
        _ = goal
        _ = policy
        let current = index
        index += 1
        if current == 0, holdFirst {
            firstHasStarted = true
            firstStarted?.resume()
            firstStarted = nil
            await withCheckedContinuation { continuation in
                firstHold = continuation
            }
        }
        guard results.indices.contains(current) else {
            throw FakePlanError.makeTodayFailed
        }
        return try results[current].get()
    }
}

enum FakePlanError: Error, Sendable {
    case makeTodayFailed
}

actor FakeAppReminderCenter: ReminderCenter {
    func authorization() async -> ReminderAuthorization { .denied }
    func requestAuthorization() async -> Bool { false }
    func pendingIds() async -> [String] { [] }
    func add(_: ReminderRequest) async throws {}
    func remove(ids _: [String]) async {}
}

private struct NoopAnalytics: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
}
