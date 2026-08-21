import Foundation

public enum SM2: Sendable {
    public static func apply(
        state: SRSState,
        quality: ReviewQuality,
        reviewedAt: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = StudyDay.defaultBoundaryHour
    ) -> SRSState {
        let q = quality.rawValue
        var easiness = updatedEasiness(state.easiness, quality: q)
        if easiness < SRSState.minimumEasiness {
            easiness = SRSState.minimumEasiness
        }

        var next = state
        next.easiness = easiness
        next.lastReviewedAt = reviewedAt
        next.lastQuality = q

        if q < 3 {
            next.repetitions = 0
            next.intervalDays = 0
            let schedule = StudyDay.failureSchedule(
                after: reviewedAt,
                calendar: calendar,
                dayBoundaryHour: dayBoundaryHour
            )
            // Keep both: 10-minute same-day gate and next-study-day 04:00 due (architecture §6.4).
            next.relearnGateAt = schedule.retryNotBefore
            next.dueAt = schedule.nextStudyDayDueAt
        } else {
            let interval: Int
            if state.repetitions == 0 {
                interval = 1
            } else if state.repetitions == 1 {
                interval = 6
            } else {
                interval = Int((Double(state.intervalDays) * easiness).rounded())
            }
            next.repetitions = state.repetitions + 1
            next.intervalDays = interval
            next.relearnGateAt = nil
            next.dueAt = StudyDay.nextDueAt(
                intervalDays: interval,
                after: reviewedAt,
                calendar: calendar,
                dayBoundaryHour: dayBoundaryHour
            )
        }
        return next
    }

    /// EF' = EF + (0.1 − (5−q)×(0.08+(5−q)×0.02))
    public static func updatedEasiness(_ easiness: Double, quality q: Int) -> Double {
        let delta = 5 - q
        return easiness + (0.1 - Double(delta) * (0.08 + Double(delta) * 0.02))
    }
}
