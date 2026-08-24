import ContentKit
import Testing

@Suite("EntitlementResolver policy")
struct EntitlementResolverTests {
    private let seed = EntitlementResolver.defaultSeedCourseID
    private let other = "course_travel_ja_en"

    @Test("store unavailable unlocks everything, including later units and composition cap")
    func storeUnavailableUnlocksAll() {
        let resolver = EntitlementResolver(
            isPro: false,
            storeAvailable: false,
            compositionsUsedToday: 99
        )
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: false) == .unlocked)
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: true) == .unlocked)
        #expect(resolver.access(courseId: seed, isFirstUnit: false, skillIsComposition: true) == .unlocked)
    }

    @Test("default init treats the store as unavailable so TestFlight stays open")
    func defaultInitUnlocks() {
        let resolver = EntitlementResolver()
        #expect(resolver.storeAvailable == false)
        #expect(resolver.isPro == false)
        #expect(resolver.seedCourseIds == [seed])
        #expect(resolver.dailyCompositionLimit == 5)
        #expect(resolver.compositionsUsedToday == 0)
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: false) == .unlocked)
    }

    @Test("Pro unlocks later units and ignores the daily composition cap")
    func proUnlocksAll() {
        let resolver = EntitlementResolver(
            isPro: true,
            storeAvailable: true,
            compositionsUsedToday: 99
        )
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: false) == .unlocked)
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: true) == .unlocked)
        #expect(resolver.access(courseId: seed, isFirstUnit: false, skillIsComposition: true) == .unlocked)
    }

    @Test("seed course is free except the daily composition cap")
    func seedCourseIsFreeUnlessCompositionCapped() {
        let under = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 4)
        #expect(under.access(courseId: seed, isFirstUnit: false, skillIsComposition: false) == .unlocked)
        #expect(under.access(courseId: seed, isFirstUnit: false, skillIsComposition: true) == .unlocked)

        let atCap = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 5)
        #expect(atCap.access(courseId: seed, isFirstUnit: true, skillIsComposition: false) == .unlocked)
        #expect(atCap.access(courseId: seed, isFirstUnit: true, skillIsComposition: true) == .locked)
    }

    @Test("first unit of a non-seed course is free except the daily composition cap")
    func firstUnitIsFreeUnlessCompositionCapped() {
        let under = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 2)
        #expect(under.access(courseId: other, isFirstUnit: true, skillIsComposition: false) == .unlocked)
        #expect(under.access(courseId: other, isFirstUnit: true, skillIsComposition: true) == .unlocked)

        let atCap = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 5)
        #expect(atCap.access(courseId: other, isFirstUnit: true, skillIsComposition: false) == .unlocked)
        #expect(atCap.access(courseId: other, isFirstUnit: true, skillIsComposition: true) == .locked)
    }

    @Test("later units of a non-seed course are locked for free users")
    func laterUnitsLockedWhenStoreAvailable() {
        let resolver = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 0)
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: false) == .locked)
        #expect(resolver.access(courseId: other, isFirstUnit: false, skillIsComposition: true) == .locked)
    }

    @Test("daily composition cap is 5 inclusive of the 5th used attempt")
    func compositionCapIsFive() {
        let four = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 4)
        #expect(four.access(courseId: seed, isFirstUnit: true, skillIsComposition: true) == .unlocked)
        let five = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 5)
        #expect(five.access(courseId: seed, isFirstUnit: true, skillIsComposition: true) == .locked)
        let six = EntitlementResolver(storeAvailable: true, compositionsUsedToday: 6)
        #expect(six.access(courseId: other, isFirstUnit: true, skillIsComposition: true) == .locked)
    }

    @Test("custom seed IDs and limit are honored")
    func customSeedAndLimit() {
        let resolver = EntitlementResolver(
            storeAvailable: true,
            seedCourseIds: ["course_custom"],
            dailyCompositionLimit: 2,
            compositionsUsedToday: 2
        )
        #expect(resolver.access(courseId: "course_custom", isFirstUnit: false, skillIsComposition: false) == .unlocked)
        #expect(resolver.access(courseId: seed, isFirstUnit: false, skillIsComposition: false) == .locked)
        #expect(resolver.access(courseId: "course_custom", isFirstUnit: true, skillIsComposition: true) == .locked)
    }
}
