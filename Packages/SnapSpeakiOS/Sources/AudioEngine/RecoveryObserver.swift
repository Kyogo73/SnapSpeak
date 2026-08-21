import AVFoundation
import Foundation

public enum RecoveryEvent: Sendable, Equatable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case routeChange
    case mediaServicesReset
    case configurationChange
}

/// Exclusive subscriber for audio recovery notifications (architecture §3.9).
public final class RecoveryObserver: @unchecked Sendable {
    private var tokens: [NSObjectProtocol] = []

    public init() {}

    public func events() -> AsyncStream<RecoveryEvent> {
        AsyncStream { continuation in
            self.start { event in
                continuation.yield(event)
            }
            continuation.onTermination = { _ in
                self.stop()
            }
        }
    }

    public func start(handler: @escaping @Sendable (RecoveryEvent) -> Void) {
        stop()
        let center = NotificationCenter.default
        tokens.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil
            ) { notification in
                handler(Self.parseInterruption(notification))
            }
        )
        tokens.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: nil
            ) { _ in
                handler(.routeChange)
            }
        )
        tokens.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: nil
            ) { _ in
                handler(.mediaServicesReset)
            }
        )
        tokens.append(
            center.addObserver(
                forName: AVAudioEngine.configurationChangeNotification,
                object: nil,
                queue: nil
            ) { _ in
                handler(.configurationChange)
            }
        )
    }

    public func stop() {
        let center = NotificationCenter.default
        for token in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    deinit { stop() }

    private static func parseInterruption(_ notification: Notification) -> RecoveryEvent {
        let info = notification.userInfo
        let typeValue = info?[AVAudioSessionInterruptionTypeKey] as? UInt
        let type = typeValue.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
        if type == .ended {
            let optionsValue = info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            return .interruptionEnded(shouldResume: options.contains(.shouldResume))
        }
        return .interruptionBegan
    }
}
