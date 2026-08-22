import DriveKit
import Foundation
import Persistence

public enum DrivePausePreset: String, Sendable, CaseIterable {
    case short
    case standard
    case long

    public var multiplier: Double {
        switch self {
        case .short: return 0.8
        case .standard: return 1.0
        case .long: return 1.3
        }
    }

    public static func from(stored: String) -> DrivePausePreset {
        DrivePausePreset(rawValue: stored) ?? .standard
    }
}

public enum DriveSettingsMapping {
    public static func sessionLength(minutes: Int) -> DriveScriptSettings.SessionLength {
        DriveScriptSettings.SessionLength(rawValue: minutes) ?? .minutes10
    }

    public static func scriptSettings(from dto: UserSettingsDTO) -> DriveScriptSettings {
        DriveScriptSettings(
            sessionLength: sessionLength(minutes: dto.driveSessionMinutes),
            pauseMultiplier: DrivePausePreset.from(stored: dto.drivePausePreset).multiplier,
            shadowingRepeats: dto.driveShadowingRepeats
        )
    }

    public static func applying(
        length: DriveScriptSettings.SessionLength? = nil,
        pause: DrivePausePreset? = nil,
        repeats: Int? = nil,
        to dto: UserSettingsDTO
    ) -> UserSettingsDTO {
        var next = dto
        if let length {
            next.driveSessionMinutes = length.rawValue
        }
        if let pause {
            next.drivePausePreset = pause.rawValue
        }
        if let repeats {
            next.driveShadowingRepeats = min(max(repeats, 1), 3)
        }
        return next
    }
}
