import AppFeature
import Foundation
import HabitKit
import Persistence
import Testing

@Suite("DashboardViewModel")
@MainActor
struct DashboardViewModelTests {
    @Test("sample(from:): shadowing 実ペイロードは scriptMatchRate を採用する")
    func sampleDecodesShadowingScore() throws {
        let rate = 0.85
        let dto = attemptDTO(skill: "shadowing", payload: try encodedShadowingScore(scriptMatchRate: rate))
        let sample = DashboardViewModel.sample(from: dto)
        #expect(sample?.mode == .shadowing)
        #expect(sample?.scriptMatchRate == rate)
        #expect(sample?.passed == nil)
        #expect(sample?.createdAt == dto.createdAt)
    }

    @Test("sample(from:): composition v2 の pass / fail / unscored")
    func sampleDecodesCompositionV2Results() {
        let pass = DashboardViewModel.sample(from: attemptDTO(skill: "composition", payload: compositionV2(result: "pass")))
        let fail = DashboardViewModel.sample(from: attemptDTO(skill: "composition", payload: compositionV2(result: "fail")))
        let unscored = DashboardViewModel.sample(from: attemptDTO(skill: "composition", payload: compositionV2(result: "unscored")))
        #expect(pass?.mode == .composition)
        #expect(pass?.passed == true)
        #expect(fail?.passed == false)
        #expect(unscored?.passed == nil)
        #expect(pass?.scriptMatchRate == nil)
    }

    @Test("sample(from:): composition v1 passed 互換")
    func sampleDecodesCompositionV1Passed() {
        let payload = Data(#"{"payloadSchemaVersion":"1","passed":"true"}"#.utf8)
        let sample = DashboardViewModel.sample(from: attemptDTO(skill: "composition", payload: payload, schema: 1))
        #expect(sample?.mode == .composition)
        #expect(sample?.passed == true)
    }

    @Test("sample(from:): 壊れ JSON と未知 schema は nil メトリクスでサンプルを維持する")
    func sampleKeepsItemWhenPayloadIsUnusable() {
        let brokenShadowing = DashboardViewModel.sample(
            from: attemptDTO(skill: "shadowing", payload: Data("not-json".utf8))
        )
        #expect(brokenShadowing?.mode == .shadowing)
        #expect(brokenShadowing?.scriptMatchRate == nil)

        let unknownComposition = DashboardViewModel.sample(
            from: attemptDTO(
                skill: "composition",
                payload: Data(#"{"payloadSchemaVersion":99,"result":"pass","usedHint":false,"latencyMs":0}"#.utf8),
                schema: 99
            )
        )
        #expect(unknownComposition?.mode == .composition)
        #expect(unknownComposition?.passed == nil)
    }

    @Test("windowStart は 04:00 境界で今学習日開始の 30 日前")
    func windowStartUsesStudyDayBoundary() {
        let calendar = utcCalendar()
        let beforeBoundary = utcDate(2026, 4, 6, 3, 59)
        let onBoundary = utcDate(2026, 4, 6, 4, 0)
        #expect(DashboardViewModel.windowStart(now: beforeBoundary, calendar: calendar) == utcDate(2026, 3, 6, 4, 0))
        #expect(DashboardViewModel.windowStart(now: onBoundary, calendar: calendar) == utcDate(2026, 3, 7, 4, 0))
    }

    @Test("load: 履歴 0 は empty")
    func loadEmptyWhenNoAttempts() async throws {
        let viewModel = try makeViewModel()
        await viewModel.load(now: utcDate(2026, 8, 21, 10, 0))
        #expect(viewModel.state == .empty)
    }

    @Test("load: 2 モードを seed すると ready の件数と平均が一致する")
    func loadReadyUsesSeededAttempts() async throws {
        let persistence = try makePersistence()
        let now = utcDate(2026, 8, 21, 10, 0)
        _ = try await persistence.appendAttempt(
            attemptWrite(skill: "shadowing", itemId: "s1", createdAt: now, payload: try encodedShadowingScore(scriptMatchRate: 0.8))
        )
        _ = try await persistence.appendAttempt(
            attemptWrite(
                skill: "shadowing",
                itemId: "s2",
                createdAt: now.addingTimeInterval(10),
                payload: try encodedShadowingScore(scriptMatchRate: 0.6)
            )
        )
        _ = try await persistence.appendAttempt(
            attemptWrite(skill: "composition", itemId: "c1", createdAt: now.addingTimeInterval(20), payload: compositionV2(result: "pass"))
        )
        _ = try await persistence.appendAttempt(
            attemptWrite(skill: "composition", itemId: "c2", createdAt: now.addingTimeInterval(30), payload: compositionV2(result: "fail"))
        )

        let viewModel = DashboardViewModel(persistence: persistence)
        await viewModel.load(now: now)

        guard case let .ready(summary) = viewModel.state else {
            Issue.record("expected ready")
            return
        }
        #expect(summary.shadowingAverageMatchRate == 0.7)
        #expect(summary.shadowingSampleCount == 2)
        #expect(summary.compositionPassRate == 0.5)
        #expect(summary.compositionScoredCount == 2)
        #expect(summary.weekCompletedItems == 4)
        #expect(summary.dailyBars.count == 7)
    }

    private func makeViewModel() throws -> DashboardViewModel {
        DashboardViewModel(persistence: try makePersistence())
    }

    private func makePersistence() throws -> PersistenceActor {
        let container = try PersistenceActor.makeContainer(inMemory: true)
        return PersistenceActor(modelContainer: container)
    }

    private func attemptDTO(skill: String, payload: Data, schema: Int = 1) -> LessonAttemptDTO {
        LessonAttemptDTO(
            id: UUID(),
            courseId: "course_daily_ja_en",
            lessonId: "lesson_01",
            itemId: "item_01",
            contentRevision: 1,
            languagePairKey: "ja>en",
            skill: skill,
            createdAt: Date(timeIntervalSince1970: 1_777_200_000),
            durationMs: 1_000,
            payloadSchemaVersion: schema,
            payloadJSON: payload
        )
    }

    private func attemptWrite(skill: String, itemId: String, createdAt: Date, payload: Data) -> LessonAttemptWrite {
        LessonAttemptWrite(
            courseId: "course_daily_ja_en",
            lessonId: "lesson_01",
            itemId: itemId,
            contentRevision: 1,
            languagePairKey: "ja>en",
            skill: skill,
            createdAt: createdAt,
            durationMs: 1_000,
            payloadSchemaVersion: 1,
            payloadJSON: payload
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT") ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return utcCalendar().date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    private func compositionV2(result: String) -> Data {
        Data(#"{"payloadSchemaVersion":2,"result":"\#(result)","usedHint":false,"latencyMs":100}"#.utf8)
    }

    /// `ScoringKit.ShadowingScore` と同形の Codable ペイロードをエンコードする。
    private func encodedShadowingScore(scriptMatchRate: Double) throws -> Data {
        try JSONEncoder().encode(
            EncodedShadowingScore(scriptMatchRate: scriptMatchRate)
        )
    }
}

private struct EncodedShadowingScore: Encodable {
    var payloadSchemaVersion = 1
    var scriptMatchRate: Double
    var precision = 1.0
    var recall = 1.0
    var omissions: [EncodedAlignedSpan] = []
    var hesitations = 0
    var substitutions = 0
    var wpm = 120.0
    var delayMsMedian: Int?
    var delayGranularity = "unavailable"
    var asrOnDevice = true
    var meanConfidence: Double?
    var minConfidence: Double?
    var audioRoute = EncodedAudioRoute()
    var playbackRate: Float = 1
    var simultaneousPlayAndRecord = true
}

private struct EncodedAlignedSpan: Encodable {
    var startRefIndex = 0
    var endRefIndex = 0
}

private struct EncodedAudioRoute: Encodable {
    var inputPortName = "mic"
    var outputPortName = "speaker"
    var isHFP = false
    var voiceProcessingEnabled = true
}
