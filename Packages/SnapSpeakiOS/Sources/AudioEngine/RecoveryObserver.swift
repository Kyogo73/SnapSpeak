import AVFoundation
import Foundation

public enum RecoveryEvent: Sendable, Equatable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case routeChange
    case mediaServicesReset
    case configurationChange
}

/// Holds NotificationCenter observer tokens outside actor isolation so that cleanup can run
/// from its own (nonisolated) deinit. Mutation is always funneled through `RecoveryObserver`,
/// whose actor isolation serializes access.
private final class ObserverTokenBox: @unchecked Sendable {
    private let center = NotificationCenter.default
    var tokens: [NSObjectProtocol] = []

    func removeAll() {
        for token in tokens {
            center.removeObserver(token)
        }
        tokens.removeAll()
    }

    deinit {
        removeAll()
    }
}

/// Exclusive subscriber for audio recovery notifications (architecture §3.9).
/// Observer tokens live only on this actor so start/stop and stream cancellation cannot race.
public actor RecoveryObserver {
    private let box = ObserverTokenBox()

    public init() {}

    public func events() -> AsyncStream<RecoveryEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.start { event in
                    continuation.yield(event)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.stop() }
            }
        }
    }

    public func start(handler: @escaping @Sendable (RecoveryEvent) -> Void) {
        stop()
        let center = NotificationCenter.default
        box.tokens.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil
            ) { notification in
                handler(Self.parseInterruption(notification))
            }
        )
        box.tokens.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: nil
            ) { _ in
                handler(.routeChange)
            }
        )
        box.tokens.append(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification,
                object: nil,
                queue: nil
            ) { _ in
                handler(.mediaServicesReset)
            }
        )
        box.tokens.append(
            center.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: nil,
                queue: nil
            ) { _ in
                handler(.configurationChange)
            }
        )
    }

    public func stop() {
        box.removeAll()
    }

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
