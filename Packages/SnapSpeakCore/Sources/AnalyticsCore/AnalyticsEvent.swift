import Foundation
import LanguageKit

/// Analytics events cannot carry raw text, audio, or personal data.
public enum AnalyticsEvent: Sendable, Equatable {
    case lessonStarted(languagePair: String, lessonId: String)
    case lessonCompleted(
        languagePair: String,
        lessonId: String,
        scoreBand: Double?,
        durationBand: String,
        routeCategory: String?
    )
    case downloadFailed(courseId: String)
    // Phase 2 reserved event IDs (not produced in Phase 1): paywall_shown, purchase_succeeded
}
