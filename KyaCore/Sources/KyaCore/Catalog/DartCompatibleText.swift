/// Text primitives that reproduce the legacy Dart `String` semantics the
/// ingredient lookup key was defined with, scalar for scalar, so keys computed
/// here match keys computed by the Dart oracle.
enum DartCompatibleText {
    /// Scalars removed by Dart's `String.trim()`.
    private static func isTrimmable(_ value: UInt32) -> Bool {
        value == 0x85 || isRegExpWhitespace(value)
    }

    /// Scalars matched by Dart's `RegExp(r'\s')` (ECMAScript `WhiteSpace` and
    /// `LineTerminator`). Unlike `trim()`, this excludes U+0085 (NEL).
    private static func isRegExpWhitespace(_ value: UInt32) -> Bool {
        switch value {
        case 0x09...0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F,
            0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    /// Dart's `text.trim()`: removes leading and trailing whitespace scalars.
    static func trim(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        result.append(contentsOf: trimmedScalars(text))
        return String(result)
    }

    private static func trimmedScalars(_ text: String) -> ArraySlice<Unicode.Scalar> {
        let scalars = Array(text.unicodeScalars)
        guard let first = scalars.firstIndex(where: { !isTrimmable($0.value) }),
            let last = scalars.lastIndex(where: { !isTrimmable($0.value) })
        else { return [] }
        return scalars[first...last]
    }

    /// Dart's `text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')`.
    ///
    /// Lower-casing is Dart's context-free, per-scalar mapping: a final capital
    /// sigma becomes `σ` (not `ς`) and `İ` (U+0130) becomes plain `i` (no
    /// combining dot), unlike Swift's `lowercased()`.
    static func trimLowercaseCollapse(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in trimmedScalars(text) {
            if isRegExpWhitespace(scalar.value) {
                pendingSpace = true
                continue
            }
            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(lowercase(scalar))
        }
        return String(result)
    }

    /// Dart's per-scalar lower-case mapping: the full Unicode mapping when it is
    /// a single scalar, otherwise its first scalar (only U+0130 has a
    /// multi-scalar full mapping, whose first scalar is its simple mapping).
    private static func lowercase(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        if scalar.isASCII {
            return scalar.properties.isUppercase
                ? Unicode.Scalar(UInt8(scalar.value) + 0x20) : scalar
        }
        return scalar.properties.lowercaseMapping.unicodeScalars.first ?? scalar
    }
}
