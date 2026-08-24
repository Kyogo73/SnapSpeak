import Foundation

public enum EntitlementAccess: String, Sendable, Equatable {
    case unlocked
    case locked
}

/// Pure free / Pro policy. StoreKit stays out of this type; callers pass a snapshot.
public struct EntitlementResolver: Sendable, Equatable {
    public var isPro: Bool
    public var storeAvailable: Bool
    public var seedCourseIds: Set<String>
    public var dailyCompositionLimit: Int
    public var compositionsUsedToday: Int

    public static let defaultSeedCourseID = "course_daily_ja_en"
    public static let defaultDailyCompositionLimit = 5

    public init(
        isPro: Bool = false,
        storeAvailable: Bool = false,
        seedCourseIds: Set<String> = [defaultSeedCourseID],
        dailyCompositionLimit: Int = defaultDailyCompositionLimit,
        compositionsUsedToday: Int = 0
    ) {
        self.isPro = isPro
        self.storeAvailable = storeAvailable
        self.seedCourseIds = seedCourseIds
        self.dailyCompositionLimit = dailyCompositionLimit
        self.compositionsUsedToday = compositionsUsedToday
    }

    /// Players only see unlocked / locked. They do not know StoreKit.
    /// `storeAvailable == false` unlocks everything so TestFlight is not bricked before IAP exists.
    public func access(
        courseId: String,
        isFirstUnit: Bool,
        skillIsComposition: Bool
    ) -> EntitlementAccess {
        if !storeAvailable { return .unlocked }
        if isPro { return .unlocked }
        if skillIsComposition, compositionsUsedToday >= dailyCompositionLimit {
            return .locked
        }
        if seedCourseIds.contains(courseId) { return .unlocked }
        if isFirstUnit { return .unlocked }
        return .locked
    }
}
