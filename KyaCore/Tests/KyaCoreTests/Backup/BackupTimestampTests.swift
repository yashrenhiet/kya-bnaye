import Foundation
import KyaCore
import Testing

/// Timestamp reading and writing through ``BackupCodec``: the Dart
/// `DateTime.parse` grammar, zone handling and range limits. Swift-only: Dart
/// kept a UTC/local flag on `DateTime`, which `Date` has no equivalent of.
@Suite("BackupCodec timestamps")
struct BackupTimestampTests {
    /// Decodes a one-meal-log backup whose `cookedAt` is `text`.
    private func cookedAt(_ text: String, zone: String = "UTC") throws -> Date {
        let codec = BackupCodec(timeZone: try #require(TimeZone(identifier: zone)))
        var json = try BackupFixtures.validJSON(codec)
        json.edit("mealLogs", at: 0) { $0["cookedAt"] = text }
        return try codec.decode(jsonObject: json).mealLogs[0].cookedAt
    }

    /// The `cookedAt` text written for `date`.
    private func written(_ date: Date) throws -> String? {
        let bundle = BackupBundle(
            mealLogs: [MealLog(id: "m", recipeId: "r", mealType: .lunch, cookedAt: date)])
        let json = try JSONText.object(try BackupCodec().encode(bundle, exportedAt: date))
        return try json.object("mealLogs")["cookedAt"] as? String
    }

    @Test("accepts the grammar of Dart's DateTime.parse")
    func dartGrammar() throws {
        let noon = try TestDates.utc(2026, 9, 26, 12)
        for text in [
            "2026-09-26T12:00:00Z", "2026-09-26 12:00:00Z", "2026-09-26T12:00:00z",
            "20260926T120000Z", "2026-09-26T12:00Z", "2026-09-26T12Z", "2026-09-26T12:00:00 Z",
            "2026-09-26T17:30:00+05:30", "2026-09-26T17:30:00+0530", "2026-09-26T07:00:00-05",
            "+002026-09-26T12:00:00Z",
        ] {
            #expect(try cookedAt(text) == noon, "\(text)")
        }
    }

    @Test("fractions: dot or comma, extra digits truncated to microseconds")
    func fractions() throws {
        let base = try TestDates.utc(2026, 9, 26, 12)
        #expect(try cookedAt("2026-09-26T12:00:00,5Z") == base.addingTimeInterval(0.5))
        #expect(try cookedAt("2026-09-26T12:00:00.1234567Z") == base.addingTimeInterval(0.123_456))
        #expect(try cookedAt("2026-09-26T12:00:00.000001Z") == base.addingTimeInterval(0.000_001))
    }

    @Test("zone-less timestamps are wall-clock time in the codec's time zone")
    func zoneless() throws {
        let expected = try TestDates.utc(2026, 9, 26, 14)
        #expect(try cookedAt("2026-09-26T19:30:00", zone: "Asia/Kolkata") == expected)
        #expect(
            try cookedAt("2026-09-26", zone: "Asia/Kolkata")
                == expected.addingTimeInterval(
                    -19.5 * 3600))
        let newYork = try TestDates.calendar(zone: "America/New_York")
        #expect(
            try cookedAt("2026-03-08T03:30:00", zone: "America/New_York")
                == (try TestDates.local(2026, 3, 8, 3, 30, calendar: newYork)))
    }

    @Test("rejects malformed and out-of-range timestamps instead of rolling over")
    func rejects() throws {
        for text in [
            "", "yesterday", "31/12/2026", "2026-13-01T00:00:00Z", "2026-02-30T00:00:00Z",
            "2025-02-29T00:00:00Z", "2026-09-26T24:00:00Z", "2026-09-26T12:60:00Z",
            "2026-09-26T12:00:60Z", "2026-09-26T12:00:00+24:00", "2026-09-26T12:00:00+05:60",
            "2026-09-26T12:00:00Z\n", " 2026-09-26T12:00:00Z",
            "\u{0662}\u{0660}\u{0662}\u{0666}-09-26T12:00:00Z",
            "2026-09-26T12:00:00.Z", "2026-9-26T12:00:00Z",
        ] {
            #expect(throws: BackupFormatError.self, "\(text)") { try cookedAt(text) }
        }
    }

    @Test("rejects timestamps outside the range it can ever write back out")
    func rejectsOutOfRoundTripRange() throws {
        // `string(from:)` refuses anything past about ±275,000 years (Dart's
        // `DateTime` range) because no clock produces it and it could never
        // be written back out. `date(from:)` must reject the same values, or
        // a restored backup could contain an instant this very codec cannot
        // re-export — silently breaking the round trip the type documents.
        for text in [
            "+275761-01-01T00:00:00.000Z", "-275761-01-01T00:00:00.000Z",
            // Zone-less input goes through a different (Calendar-based) code
            // path than a zoned timestamp; it needs the same guard.
            "+275761-01-01T00:00:00",
        ] {
            #expect(throws: BackupFormatError.self, "\(text)") { try cookedAt(text) }
        }
        // A whole-seconds value that sits exactly at the limit still
        // overflows once a fractional second pushes it past — the guard must
        // check the combined instant, not just the whole seconds.
        #expect(throws: BackupFormatError.self) {
            try cookedAt("+275760-09-13T00:00:00.5Z")
        }
        // Just inside the range still round-trips.
        let edge = try cookedAt("+275760-09-13T00:00:00.000Z")
        #expect(try written(edge) == "+275760-09-13T00:00:00.000Z")
    }

    @Test("accepts leap days")
    func leapDays() throws {
        for (text, year) in [("2024-02-29", 2024), ("2000-02-29", 2000)] {
            #expect(try cookedAt(text) == (try TestDates.utc(year, 2, 29)))
        }
        #expect(throws: BackupFormatError.self) { try cookedAt("1900-02-29") }
    }

    @Test("writes UTC with millisecond or microsecond precision, like Dart's UTC output")
    func writing() throws {
        let noon = try TestDates.utc(2026, 9, 26, 12)
        #expect(try written(noon) == "2026-09-26T12:00:00.000Z")
        #expect(try written(noon.addingTimeInterval(0.5)) == "2026-09-26T12:00:00.500Z")
        #expect(try written(noon.addingTimeInterval(0.000_012)) == "2026-09-26T12:00:00.000012Z")
        #expect(try written(noon.addingTimeInterval(0.999_999_7)) == "2026-09-26T12:00:01.000Z")
        #expect(try written(noon.addingTimeInterval(-0.25)) == "2026-09-26T11:59:59.750Z")
    }

    @Test("writes and reads years outside 1970–9999")
    func extremeYears() throws {
        let cases: [(Date, String)] = [
            (Date(timeIntervalSince1970: -0.5), "1969-12-31T23:59:59.500Z"),
            // Proleptic Gregorian, like Dart; `Date.distantPast` is Julian
            // 0001-01-01, i.e. two days earlier.
            (Date(timeIntervalSince1970: -62_135_596_800), "0001-01-01T00:00:00.000Z"),
            (.distantPast, "0000-12-30T00:00:00.000Z"),
            (.distantFuture, "4001-01-01T00:00:00.000Z"),
            (Date(timeIntervalSince1970: 253_402_300_800), "+010000-01-01T00:00:00.000Z"),
            (Date(timeIntervalSince1970: -62_198_755_200), "-0001-01-01T00:00:00.000Z"),
        ]
        for (date, text) in cases {
            #expect(try written(date) == text)
            #expect(try cookedAt(text) == date, "\(text)")
        }
    }

    @Test("round-trips instants at microsecond precision across many values")
    func roundTripSweep() throws {
        let start = try TestDates.utc(2026, 1, 1)
        for step in 0..<500 {
            let micros = step * 7_919_993_123
            let date = start.addingTimeInterval(Double(micros / 1_000_000))
                .addingTimeInterval(Double(micros % 1_000_000) / 1_000_000)
            let text = try #require(try written(date))
            #expect(try cookedAt(text) == date, "\(text)")
        }
    }

    @Test("dates no clock produces fail to encode with the field path")
    func unrepresentable() throws {
        let valid = try TestDates.utc(2026, 9, 26)
        let bad = Date(timeIntervalSinceReferenceDate: .infinity)
        let pantry = BackupBundle(
            pantryItems: [
                PantryItem(ingredientId: "a", level: .low, updatedAt: valid),
                PantryItem(ingredientId: "b", level: .low, updatedAt: valid, expiresOn: bad),
            ])
        #expect(throws: BackupEncodingError.unrepresentableDate(field: "pantryItems[1].expiresOn"))
        {
            try BackupCodec().encode(pantry, exportedAt: valid)
        }
        #expect(throws: BackupEncodingError.unrepresentableDate(field: "exportedAt")) {
            try BackupCodec().encode(BackupBundle(), exportedAt: bad)
        }
        let farFuture = Date(timeIntervalSince1970: 8.7e12)
        let cases: [(BackupBundle, String)] = [
            (
                BackupBundle(pantryItems: [
                    PantryItem(ingredientId: "a", level: .low, updatedAt: farFuture)
                ]), "pantryItems[0].updatedAt"
            ),
            (
                BackupBundle(swipeEvents: [
                    SwipeEvent(
                        id: "e", recipeId: "r", action: .left, mode: .kitchen, at: farFuture,
                        deckSeed: 0)
                ]), "swipeEvents[0].at"
            ),
            (
                BackupBundle(shoppingItems: [
                    try ShoppingItem(
                        id: "s", customName: "x", reason: .manual, isChecked: false,
                        createdAt: farFuture)
                ]), "shoppingItems[0].createdAt"
            ),
            (
                BackupBundle(mealLogs: [
                    MealLog(
                        id: "m", recipeId: "r", mealType: .lunch,
                        cookedAt: .init(
                            timeIntervalSinceReferenceDate: .nan))
                ]), "mealLogs[0].cookedAt"
            ),
        ]
        for (bundle, field) in cases {
            #expect(throws: BackupEncodingError.unrepresentableDate(field: field)) {
                try BackupCodec().encode(bundle, exportedAt: valid)
            }
        }
        #expect(
            BackupEncodingError.unrepresentableDate(field: "x").description
                == "BackupEncodingError: x is not a representable date")
        #expect(
            BackupEncodingError.serializationFailed(detail: "boom").description
                == "BackupEncodingError: boom")
    }
}
