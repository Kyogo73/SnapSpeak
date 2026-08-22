import DesignSystem
import DriveKit
import Foundation

/// TTS / NowPlaying 向け。Text() を通らないため String(localized:) を明示する。
public enum DriveAnnouncementText {
    public static func resolve(_ announcement: DriveAnnouncement) -> String {
        switch announcement {
        case let .sessionIntro(_, _, isRepeatFill, isEndless):
            if isEndless {
                return localized("drive.announce.intro_endless")
            }
            if isRepeatFill {
                return localized("drive.announce.intro_repeat_fill")
            }
            return LocalizedFormat.string(
                "drive.announce.intro",
                announcementDueCount(announcement),
                announcementNewCount(announcement)
            )
        case .newLessonSection:
            return localized("drive.announce.new_section")
        case .sessionOutro:
            return localized("drive.announce.outro")
        }
    }

    public static func outro(completedCount: Int) -> String {
        LocalizedFormat.string("drive.announce.outro", completedCount)
    }

    public static func texts(for script: DriveScript) -> [DriveAnnouncement: String] {
        var result: [DriveAnnouncement: String] = [:]
        for phase in script.phases {
            guard case let .announcement(announcement) = phase.audio else { continue }
            if case .sessionOutro = announcement { continue }
            result[announcement] = resolve(announcement)
        }
        return result
    }

    public static func nowPlayingTitle() -> String {
        localized("drive.nowplaying.title")
    }

    public static func nowPlayingArtist(courseTitle: String, completed: Int, planned: Int) -> String {
        let progress = LocalizedFormat.string("drive.glance.progress", completed, max(planned, 1))
        if courseTitle.isEmpty { return progress }
        return "\(courseTitle) \(progress)"
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key), bundle: .main)
    }

    private static func announcementDueCount(_ announcement: DriveAnnouncement) -> Int {
        if case let .sessionIntro(dueCount, _, _, _) = announcement { return dueCount }
        return 0
    }

    private static func announcementNewCount(_ announcement: DriveAnnouncement) -> Int {
        if case let .sessionIntro(_, newCount, _, _) = announcement { return newCount }
        return 0
    }
}
