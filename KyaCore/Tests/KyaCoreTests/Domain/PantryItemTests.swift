import Foundation
import KyaCore
import Testing

@Suite("PantryItem")
struct PantryItemTests {
    private let updatedAt: Date
    private let expiresOn: Date

    init() throws {
        updatedAt = try TestDates.local(2025, 6, 1, 9, 30)
        expiresOn = try TestDates.local(2025, 6, 10)
    }

    private func item(
        ingredientId: String = "milk",
        level: StockLevel = .plenty,
        expires: Date? = nil,
        estimated: Bool = false
    ) -> PantryItem {
        PantryItem(
            ingredientId: ingredientId,
            level: level,
            updatedAt: updatedAt,
            expiresOn: expires,
            expiryIsEstimated: estimated
        )
    }

    private func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) throws -> Date {
        try TestDates.local(y, m, d, h, min)
    }

    @Test("defaults to no expiry and a non-estimated expiry flag")
    func defaults() {
        let pantryItem = PantryItem(ingredientId: "salt", level: .low, updatedAt: updatedAt)

        #expect(pantryItem.expiresOn == nil)
        #expect(!pantryItem.expiryIsEstimated)
    }

    // MARK: equality

    @Test("items with identical fields are equal with equal hashes")
    func equalItems() {
        let a = item(expires: expiresOn, estimated: true)
        let b = item(expires: expiresOn, estimated: true)

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("differs when any single field differs")
    func anyFieldDiffers() throws {
        let base = item(expires: expiresOn)

        #expect(base.copy(ingredientId: "curd") != base)
        #expect(base.copy(level: .out) != base)
        #expect(base.copy(updatedAt: updatedAt.addingTimeInterval(1)) != base)
        #expect(base.withExpiresOn(try local(2025, 6, 11)) != base)
        #expect(base.withExpiresOn(nil) != base)
        #expect(base.copy(expiryIsEstimated: true) != base)
    }

    // MARK: copy

    @Test("copy with no arguments yields an equal item")
    func copyNoArguments() {
        let base = item(expires: expiresOn, estimated: true)

        #expect(base.copy() == base)
    }

    @Test("copy leaves an existing expiry unchanged")
    func copyKeepsExpiry() {
        let copy = item(expires: expiresOn).copy(level: .low)

        #expect(copy.expiresOn == expiresOn)
        #expect(copy.level == .low)
    }

    @Test("withExpiresOn(nil) clears the expiry")
    func clearExpiry() {
        let base = item(expires: expiresOn, estimated: true)

        let cleared = base.withExpiresOn(nil)

        #expect(cleared.expiresOn == nil)
        #expect(cleared.expiryIsEstimated)
        #expect(cleared.ingredientId == base.ingredientId)
    }

    @Test("withExpiresOn replaces the old expiry")
    func replaceExpiry() throws {
        let later = try local(2025, 7, 1)

        #expect(item(expires: expiresOn).withExpiresOn(later).expiresOn == later)
    }

    @Test("can set an expiry on an item that had none")
    func setExpiry() {
        #expect(item().withExpiresOn(expiresOn).expiresOn == expiresOn)
    }

    // MARK: daysUntilExpiry

    @Test("daysUntilExpiry is nil when there is no expiry")
    func noExpiryDays() {
        #expect(item().daysUntilExpiry(asOf: updatedAt) == nil)
    }

    @Test("counts whole calendar days, ignoring time of day")
    func wholeCalendarDays() throws {
        let pantryItem = item(expires: try local(2025, 6, 10, 0, 1))

        #expect(pantryItem.daysUntilExpiry(asOf: try local(2025, 6, 9, 23, 59)) == 1)
        #expect(pantryItem.daysUntilExpiry(asOf: try local(2025, 6, 10, 23, 59)) == 0)
    }

    @Test("is zero on the expiry day itself")
    func zeroOnExpiryDay() throws {
        let pantryItem = item(expires: try local(2025, 6, 10, 18))

        #expect(pantryItem.daysUntilExpiry(asOf: try local(2025, 6, 10, 8)) == 0)
    }

    @Test("is negative once the expiry date has passed")
    func negativeWhenPassed() throws {
        #expect(item(expires: expiresOn).daysUntilExpiry(asOf: try local(2025, 6, 13)) == -3)
    }

    @Test("spans month and year boundaries correctly")
    func monthAndYearBoundaries() throws {
        let pantryItem = item(expires: try local(2026, 1, 2))

        #expect(pantryItem.daysUntilExpiry(asOf: try local(2025, 12, 30)) == 3)
    }

    @Test("handles a leap day")
    func leapDay() throws {
        let pantryItem = item(expires: try local(2024, 3, 1))

        #expect(pantryItem.daysUntilExpiry(asOf: try local(2024, 2, 28)) == 2)
    }

    /// In a DST zone (e.g. `TZ=America/New_York`) the local-midnight difference
    /// on a spring-forward day is 23 h; seconds/86 400 would truncate it to 0.
    @Test("is exactly 1 for \"tomorrow\" on every day of the year (process time zone)")
    func tomorrowEveryDayLocal() throws {
        try assertTomorrowIsOneEveryDay(calendar: .kyaDefault)
    }

    @Test(
        "is exactly 1 for \"tomorrow\" on every day of the year (explicit zones)",
        arguments: ["America/New_York", "Europe/London", "America/Havana", "Australia/Lord_Howe"])
    func tomorrowEveryDayZone(zone: String) throws {
        try assertTomorrowIsOneEveryDay(calendar: try TestDates.calendar(zone: zone))
    }

    private func assertTomorrowIsOneEveryDay(calendar: Calendar) throws {
        var day = try TestDates.local(2025, calendar: calendar)
        var failures: [Date] = []
        while calendar.component(.year, from: day) == 2025 {
            let components = calendar.dateComponents([.year, .month, .day], from: day)
            let next = try #require(
                calendar.date(
                    from: DateComponents(
                        year: components.year, month: components.month,
                        day: (components.day ?? 0) + 1)))
            let pantryItem = item(expires: next)
            if pantryItem.daysUntilExpiry(asOf: day, calendar: calendar) != 1 {
                failures.append(day)
            }
            day = next
        }
        #expect(failures.isEmpty)
    }

    @Test("an explicit calendar decides which date an instant falls on")
    func explicitCalendar() throws {
        let expiry = try TestDates.utc(2025, 6, 10, 20)
        let now = try TestDates.utc(2025, 6, 10, 1)
        let pantryItem = item(expires: expiry)
        #expect(pantryItem.daysUntilExpiry(asOf: now, calendar: TestDates.utcCalendar) == 0)
        let kolkata = try TestDates.calendar(zone: "Asia/Kolkata")
        #expect(pantryItem.daysUntilExpiry(asOf: now, calendar: kolkata) == 1)
    }

    // MARK: isExpiringWithin

    @Test("isExpiringWithin is false when there is no expiry")
    func expiringNoExpiry() {
        #expect(!item().isExpiringWithin(365, asOf: updatedAt))
    }

    @Test("isExpiringWithin is inclusive of the boundary day")
    func expiringBoundary() throws {
        let pantryItem = item(expires: expiresOn)
        let now = try local(2025, 6, 7)

        #expect(pantryItem.isExpiringWithin(3, asOf: now))
        #expect(!pantryItem.isExpiringWithin(2, asOf: now))
    }

    @Test("treats already-expired items as expiring")
    func expiredIsExpiring() throws {
        #expect(item(expires: expiresOn).isExpiringWithin(0, asOf: try local(2025, 6, 20)))
    }

    @Test("a zero-day window matches only today or earlier")
    func zeroDayWindow() throws {
        let pantryItem = item(expires: expiresOn)

        #expect(pantryItem.isExpiringWithin(0, asOf: try local(2025, 6, 10)))
        #expect(!pantryItem.isExpiringWithin(0, asOf: try local(2025, 6, 9)))
    }

    // MARK: expiry estimation

    @Test("estimates expiry as shelf-life calendar days after the update date")
    func estimatedExpiry() throws {
        let estimate = PantryItem.estimatedExpiry(updatedAt: updatedAt, shelfLifeDays: 7)

        #expect(estimate == (try local(2025, 6, 8)))
        #expect(PantryItem.estimatedExpiry(updatedAt: updatedAt, shelfLifeDays: nil) == nil)
    }

    @Test("estimation across a DST change lands on the right calendar date")
    func estimatedExpiryAcrossDST() throws {
        let newYork = try TestDates.calendar(zone: "America/New_York")
        let bought = try TestDates.local(2025, 3, 8, 21, calendar: newYork)
        let estimate = try #require(
            PantryItem.estimatedExpiry(updatedAt: bought, shelfLifeDays: 2, calendar: newYork))

        #expect(estimate == (try TestDates.local(2025, 3, 10, calendar: newYork)))
        let restocked = PantryItem(ingredientId: "milk", level: .plenty, updatedAt: bought)
            .withEstimatedExpiry(shelfLifeDays: 2, calendar: newYork)
        #expect(restocked.daysUntilExpiry(asOf: bought, calendar: newYork) == 2)
    }

    @Test("withEstimatedExpiry sets the date and the estimated flag")
    func withEstimatedExpiry() throws {
        let estimated = item().withEstimatedExpiry(shelfLifeDays: 3)

        #expect(estimated.expiresOn == (try local(2025, 6, 4)))
        #expect(estimated.expiryIsEstimated)
        #expect(estimated.daysUntilExpiry(asOf: updatedAt) == 3)
    }

    @Test("withEstimatedExpiry with no shelf life clears the expiry and flag")
    func withEstimatedExpiryNoShelfLife() {
        let cleared = item(expires: expiresOn, estimated: true).withEstimatedExpiry(
            shelfLifeDays: nil)

        #expect(cleared.expiresOn == nil)
        #expect(!cleared.expiryIsEstimated)
    }

    @Test("description shows the ingredient id and level")
    func description() {
        #expect(item(level: .low).description == "PantryItem(milk: StockLevel.low)")
    }

    @Test("StockLevel: plenty and low count as available; out does not")
    func stockLevelAvailability() {
        #expect(StockLevel.plenty.isAvailable)
        #expect(StockLevel.low.isAvailable)
        #expect(!StockLevel.out.isAvailable)
    }
}
