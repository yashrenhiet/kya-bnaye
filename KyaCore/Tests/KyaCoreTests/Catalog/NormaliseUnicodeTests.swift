import KyaCore
import Testing

/// Expected values were produced by running the Dart oracle's
/// `IngredientNormalizer.normalise` / constructor on the same inputs.
@Suite("IngredientNormalizer Dart parity (Unicode and duplicates)")
struct NormaliseUnicodeTests {
    private func scalars(_ text: String) -> [UInt32] {
        text.unicodeScalars.map(\.value)
    }

    static let cases: [(input: String, expected: [UInt32])] = [
        // NEL is trimmed by Dart's trim() but is not \s, so it survives inside.
        ("\u{85}a\u{85}b\u{85}", [0x61, 0x85, 0x62]),
        ("\u{A0}a\u{A0}\u{A0}b\u{A0}", [0x61, 0x20, 0x62]),
        // Zero-width space is not whitespace; BOM and ideographic space are.
        ("\u{FEFF}a\u{200B}b\u{3000}", [0x61, 0x200B, 0x62]),
        ("\u{0B}a\u{0C}\u{0C}b", [0x61, 0x20, 0x62]),
        ("a\u{FEFF}b", [0x61, 0x20, 0x62]),
        ("a\u{202F}b", [0x61, 0x20, 0x62]),
        ("a\u{205F}\u{2000}b", [0x61, 0x20, 0x62]),
        ("A\u{1680}\u{2028}B", [0x61, 0x20, 0x62]),
        // Mongolian vowel separator is no longer whitespace.
        ("\u{180E}x\u{180E}", [0x180E, 0x78, 0x180E]),
        // Context-free, per-scalar lower-casing.
        ("\u{130}stanbul", [0x69, 0x73, 0x74, 0x61, 0x6E, 0x62, 0x75, 0x6C]),
        ("\u{39F}\u{394}\u{39F}\u{3A3}", [0x3BF, 0x3B4, 0x3BF, 0x3C3]),
        ("\u{1E9E}", [0xDF]),
        ("\u{1C5}", [0x1C6]),
        ("x\u{85}", [0x78]),
        ("\u{85}", []),
    ]

    @Test("matches Dart scalar for scalar", arguments: cases)
    func dartParity(input: String, expected: [UInt32]) {
        #expect(scalars(IngredientNormalizer.normalise(input)) == expected)
    }

    @Test("a repeated id keeps the first position but the last value")
    func duplicateIds() throws {
        let normalizer = try IngredientNormalizer([
            makeIngredient("a", "A"), makeIngredient("b", "B"), makeIngredient("a", "A2"),
        ])

        #expect(normalizer.all.map(\.name) == ["A2", "B"])
        #expect(normalizer.find("A") == nil)
        #expect(normalizer.find("A2")?.id == "a")
    }

    @Test("user ids keep non-ASCII letters")
    func nonASCIIUserId() throws {
        let created = try IngredientNormalizer.createUserIngredient(
            "Café Noir", category: .other, buyFrom: .other)
        #expect(created.id == "user_café_noir")
    }
}
