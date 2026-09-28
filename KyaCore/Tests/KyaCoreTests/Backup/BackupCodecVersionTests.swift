import Foundation
import KyaCore
import Testing

/// Schema versions: schema 2 (current) records the seed version; schema 1 files, written
/// by the legacy Dart app and earlier builds, still restore.
@Suite("BackupCodec versions")
struct BackupCodecVersionTests {
    let codec = BackupCodec()

    /// The full fixture as a schema-1 document: version 1 and no `seedVersion` key.
    private func schema1JSON() throws -> [String: Any] {
        var json = try BackupFixtures.validJSON(codec)
        json["version"] = 1
        json["seedVersion"] = nil
        return json
    }

    @Test("a schema-1 file decodes every entity, with an unknown seed version")
    func readsSchema1() throws {
        let decoded = try codec.decode(jsonObject: try schema1JSON())
        #expect(decoded.seedVersion == nil)
        let want = try BackupFixtures.fullBundle()
        BackupFixtures.expectEqual(
            decoded,
            BackupBundle(
                ingredients: want.ingredients, pantryItems: want.pantryItems,
                recipes: want.recipes, mealLogs: want.mealLogs, swipeEvents: want.swipeEvents,
                shoppingItems: want.shoppingItems))
    }

    @Test("a schema-1 file read from bytes decodes too")
    func readsSchema1Bytes() throws {
        let data = try JSONSerialization.data(withJSONObject: try schema1JSON())
        #expect(try codec.decode(data).recipes.count == 2)
    }

    @Test("a null seed version means unknown")
    func nullSeedVersion() throws {
        var json = try BackupFixtures.validJSON(codec)
        json["seedVersion"] = NSNull()
        #expect(try codec.decode(jsonObject: json).seedVersion == nil)
    }

    @Test("the seed version round-trips through file bytes")
    func roundTrip() throws {
        let data = try codec.encode(
            BackupBundle(seedVersion: 12), exportedAt: try BackupFixtures.exportedAt())
        #expect(try codec.decode(data).seedVersion == 12)
    }

    @Test(
        "rejects a seed version that is not an integer of at least 1",
        arguments: ["0", "-3", "1.0", "true", #""3""#, "[3]"])
    func rejectsBadSeedVersion(_ literal: String) throws {
        var json = try BackupFixtures.validJSON(codec)
        json["seedVersion"] = try JSONSerialization.jsonObject(
            with: Data(literal.utf8), options: [.fragmentsAllowed])
        let error = try #require(BackupFixtures.decodeError(json, codec: codec))
        guard case .malformed(let detail) = error else {
            Issue.record("expected malformed, got \(error)")
            return
        }
        #expect(detail.hasPrefix("seedVersion: expected an integer ≥ 1, got "))
    }

    @Test("a version newer than the current schema is still refused")
    func refusesNewer() throws {
        var json = try BackupFixtures.validJSON(codec)
        json["version"] = BackupCodec.currentVersion + 1
        #expect(
            BackupFixtures.decodeError(json, codec: codec)
                == .unsupportedVersion(found: "\(BackupCodec.currentVersion + 1)"))
    }
}
