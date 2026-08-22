import Foundation
import MediaPlayer

/// `MPRemoteCommandCenter` / NowPlaying の薄い橋。進行判断は持たない。
@MainActor
public final class DriveRemoteCommandBridge {
    private var sequencer: (any DriveSequencing)?
    private var registrations: [(MPRemoteCommand, Any)] = []
    private var enabledSnapshots: [(MPRemoteCommand, Bool)] = []
    private var isPaused = true

    public init() {}

    public func attach(sequencer: any DriveSequencing) {
        detach()
        self.sequencer = sequencer
        let center = MPRemoteCommandCenter.shared()
        register(center.playCommand) {
            Task { await sequencer.resume() }
        }
        register(center.pauseCommand) {
            Task { await sequencer.pause() }
        }
        register(center.togglePlayPauseCommand) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isPaused {
                    await sequencer.resume()
                } else {
                    await sequencer.pause()
                }
            }
        }
        register(center.nextTrackCommand) {
            Task { await sequencer.skipForward() }
        }
        register(center.previousTrackCommand) {
            Task { await sequencer.skipBackward() }
        }
        disable(center.changePlaybackPositionCommand)
        disable(center.skipForwardCommand)
        disable(center.skipBackwardCommand)
        disable(center.seekForwardCommand)
        disable(center.seekBackwardCommand)
        disable(center.changePlaybackRateCommand)
    }

    public func detach() {
        for (command, token) in registrations {
            command.removeTarget(token)
        }
        registrations = []
        for (command, enabled) in enabledSnapshots {
            command.isEnabled = enabled
        }
        enabledSnapshots = []
        sequencer = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    public func updateNowPlaying(title: String, artist: String, isPaused: Bool) {
        self.isPaused = isPaused
        let center = MPNowPlayingInfoCenter.default()
        center.playbackState = isPaused ? .paused : .playing
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0,
            MPNowPlayingInfoPropertyPlaybackState: isPaused
                ? MPNowPlayingPlaybackState.paused.rawValue
                : MPNowPlayingPlaybackState.playing.rawValue
        ]
        center.nowPlayingInfo = info
    }

    private func register(_ command: MPRemoteCommand, handler: @escaping () -> Void) {
        snapshotEnabled(command)
        command.isEnabled = true
        let token = command.addTarget { _ in
            handler()
            return .success
        }
        registrations.append((command, token))
    }

    private func disable(_ command: MPRemoteCommand) {
        snapshotEnabled(command)
        command.isEnabled = false
    }

    private func snapshotEnabled(_ command: MPRemoteCommand) {
        enabledSnapshots.append((command, command.isEnabled))
    }
}
