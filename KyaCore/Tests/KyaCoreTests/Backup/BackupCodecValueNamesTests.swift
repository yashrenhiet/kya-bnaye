import Foundation
import KyaCore
import Testing

/// How odd values are named in backup errors: Dart `runtimeType` spellings
/// for non-list sections, Dart interpolation for versions, and values a JSON
/// parser never produces (possible through `decode(jsonObject:)`).
@Suite("BackupCodec value names")
struct BackupCodecValueNamesTests {
    /// A value that JSON never produces, for `decode(jsonObject:)` callers.
    private struct Opaque {}

    @Test(
        "a non-list section names its Dart runtime type",
        arguments: [
            "String", "int", "double", "bool", "_Map<String, dynamic>", "Opaque",
        ])
    func sectionWrongType(expected: String) throws {
        let values: [String: Any] = [
            "String": "x", "int": 5, "double": 1.5, "bool": true,
            "_Map<String, dynamic>": [String: Any](), "Opaque": Opaque(),
        ]
        var json = try BackupFixtures.validJSON()
        json["recipes"] = values[expected]
        #expect(
            BackupFixtures.decodeError(json)
                == .sectionNotAList(section: "recipes", found: expected))
    }

    @Test("odd version values are rendered like Dart interpolation")
    func versionText() throws {
        var json = try BackupFixtures.validJSON()
        json["version"] = ["b": [true, 1.5, NSNull()], "a": 1] as [String: Any]
        #expect(
            BackupFixtures.decodeError(json)
                == .unsupportedVersion(found: "{a: 1, b: [true, 1.5, null]}"))
        json["version"] = Opaque()
        #expect(BackupFixtures.decodeError(json) == .unsupportedVersion(found: "Opaque"))
    }

    @Test("integers beyond Int64 are not a supported version")
    func hugeVersion() throws {
        var json = try BackupFixtures.validJSON()
        json["version"] = 987_654_321
        let text = String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self)
            .replacingOccurrences(of: "987654321", with: "9223372036854775808")
        #expect(text.contains("9223372036854775808"))
        #expect(throws: BackupFormatError.self) {
            try BackupCodec().decode(JSONText.data(text))
        }
    }

    @Test("a foreign value in an entity field is described by its type")
    func foreignFieldValue() throws {
        var json = try BackupFixtures.validJSON()
        json.edit("ingredients", at: 0) { $0["id"] = Opaque() }
        let message = BackupFixtures.decodeError(json)?.message ?? ""
        #expect(message.contains("got a Opaque"), "\(message)")
    }
}
