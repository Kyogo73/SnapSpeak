import Foundation

/// Resettable anonymous install identifier. Stored in UserDefaults (Required Reason API CA92.1).
public enum InstallID {
    public static let defaultsKey = "snapspeak.installID"

    public static func current(defaults: UserDefaults = .standard) -> UUID {
        if let existing = defaults.string(forKey: defaultsKey), let uuid = UUID(uuidString: existing) {
            return uuid
        }
        return reset(defaults: defaults)
    }

    @discardableResult
    public static func reset(defaults: UserDefaults = .standard) -> UUID {
        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: defaultsKey)
        return uuid
    }
}
