import AnalyticsCore
import Foundation
import os

/// Phase 1 analytics sink: local os.Logger only. No network, no personal data.
public struct LocalAnalytics: AnalyticsClient {
    private let logger: Logger

    public init(subsystem: String = "app.snapspeak", category: String = "analytics") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func track(_ event: AnalyticsEvent) {
        switch event {
        case let .lessonStarted(languagePair, lessonId):
            logger.log("lesson_started pair=\(languagePair, privacy: .public) lesson=\(lessonId, privacy: .public)")
        case let .lessonCompleted(languagePair, lessonId, scoreBand, durationBand, routeCategory):
            let band = scoreBand.map { String($0) } ?? "none"
            let route = routeCategory ?? "none"
            logger.log(
                """
                lesson_completed pair=\(languagePair, privacy: .public) \
                lesson=\(lessonId, privacy: .public) band=\(band, privacy: .public) \
                duration=\(durationBand, privacy: .public) route=\(route, privacy: .public)
                """
            )
        case let .downloadFailed(courseId):
            logger.log("download_failed course=\(courseId, privacy: .public)")
        }
    }
}
