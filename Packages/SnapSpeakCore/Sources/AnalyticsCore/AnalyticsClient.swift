import Foundation

public protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
}
