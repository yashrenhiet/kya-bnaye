/// Why an ``IngredientNormalizer`` operation failed.
public enum IngredientNormalizerError: Error, Sendable, Equatable, CustomStringConvertible {
    /// Two different ingredients normalise a name or alias to the same lookup
    /// `key`. `existingId` registered it first; `conflictingId` collided.
    case aliasCollision(key: String, existingId: String, conflictingId: String)

    /// ``IngredientNormalizer/createUserIngredient(_:category:buyFrom:role:)``
    /// was given blank or whitespace-only `text`.
    case blankName(text: String)

    /// Human-readable explanation naming the key and both ingredient ids.
    public var description: String {
        switch self {
        case .aliasCollision(let key, let existingId, let conflictingId):
            return "Alias collision: \"\(key)\" maps to both \"\(existingId)\" and "
                + "\"\(conflictingId)\". Seed validation must catch this before it ships."
        case .blankName:
            return "A user ingredient needs a name; the text must not be blank."
        }
    }
}

/// Resolves free-typed ingredient text ("aloo", "Tamatar", "  Potato ") to a
/// canonical ``Ingredient``.
///
/// The guardrail behind the most important matching rule (`AGENTS.md`
/// section 5.4): **matching is exact on the normalised name/alias key, never a
/// substring match** — "rice" never matches "rice flour". Every lookup is a
/// dictionary hit against keys built once in the initializer.
///
/// Keys are compared as Swift `String`s, i.e. up to Unicode canonical
/// equivalence (precomposed "é" equals "e" + U+0301). The Dart original
/// compared code units, so it treated those as different.
public struct IngredientNormalizer: Sendable {
    /// Every catalog ingredient exactly once, in first-seen catalog order. When
    /// the catalog repeats an id, the last occurrence wins (at the first
    /// occurrence's position) and only its name/aliases are registered.
    public let all: [Ingredient]

    private let ingredientsById: [String: Ingredient]
    private let idsByKey: [String: String]

    /// Builds the lookup index for `catalog`.
    ///
    /// Blank names/aliases are ignored, so blank input can never resolve. The
    /// same key repeated within one ingredient (or an alias equal to its own
    /// name) is harmless.
    ///
    /// - Parameter catalog: The ingredients to index.
    /// - Throws: ``IngredientNormalizerError/aliasCollision(key:existingId:conflictingId:)``
    ///   when two different ingredients share a normalised name or alias.
    public init(_ catalog: some Sequence<Ingredient>) throws(IngredientNormalizerError) {
        var order: [String] = []
        var byId: [String: Ingredient] = [:]
        for ingredient in catalog {
            if byId.updateValue(ingredient, forKey: ingredient.id) == nil {
                order.append(ingredient.id)
            }
        }
        let all = order.compactMap { byId[$0] }

        var idsByKey: [String: String] = [:]
        for ingredient in all {
            for text in [ingredient.name] + ingredient.aliases {
                let key = Self.normalise(text)
                if key.isEmpty { continue }
                if let existing = idsByKey[key], existing != ingredient.id {
                    throw .aliasCollision(
                        key: key, existingId: existing, conflictingId: ingredient.id)
                }
                idsByKey[key] = ingredient.id
            }
        }

        self.all = all
        self.ingredientsById = byId
        self.idsByKey = idsByKey
    }

    /// The lookup key for `text`: trimmed, lower-cased, with every run of
    /// whitespace collapsed to one space. Two strings refer to the same catalog
    /// entry exactly when their keys are equal; blank text yields `""`.
    /// Punctuation and underscores are kept. Public so seed validators check
    /// collisions with exactly the rule ``find(_:)`` applies at runtime.
    ///
    /// Reproduces the Dart oracle's scalar-level behaviour (Dart `trim()`
    /// whitespace, ECMAScript `\s`, context-free lower-casing).
    ///
    /// - Parameter text: Any user or seed text.
    /// - Returns: The normalised key.
    public static func normalise(_ text: String) -> String {
        DartCompatibleText.trimLowercaseCollapse(text)
    }

    /// Looks up an ingredient by exact name or alias (case- and
    /// whitespace-insensitive via ``normalise(_:)``). Never matches on the raw
    /// id and never invents an ingredient.
    ///
    /// - Parameter text: Free-typed text.
    /// - Returns: The matching ingredient, or `nil` for unknown or blank text.
    public func find(_ text: String) -> Ingredient? {
        let key = Self.normalise(text)
        guard !key.isEmpty, let id = idsByKey[key] else { return nil }
        return ingredientsById[id]
    }

    /// Whether `text` matches something in the catalog.
    ///
    /// - Parameter text: Free-typed text.
    /// - Returns: `true` exactly when ``find(_:)`` returns non-`nil`.
    public func contains(_ text: String) -> Bool {
        find(text) != nil
    }

    /// Exact, case-sensitive lookup by canonical id. Does not resolve names or
    /// aliases.
    ///
    /// - Parameter id: A canonical ``Ingredient/id``.
    /// - Returns: The ingredient, or `nil` if the id is not in the catalog.
    public func ingredient(withId id: String) -> Ingredient? {
        ingredientsById[id]
    }

    /// Builds a new user-created ingredient for text that matched nothing.
    ///
    /// The id is `"user_"` plus the normalised text with spaces replaced by
    /// underscores (the prefix keeps it from colliding with seed ids); the name
    /// is the trimmed text; aliases are empty and shelf life is `nil`. The new
    /// ingredient is **not** registered anywhere — the caller persists it and
    /// includes it when building future normalizers.
    ///
    /// - Parameters:
    ///   - text: What the user typed.
    ///   - category: Pantry-screen grouping.
    ///   - buyFrom: Shopping-screen vendor grouping.
    ///   - role: Scoring importance; defaults to ``IngredientRole/core``.
    /// - Returns: The new ingredient, with `isUserCreated == true`.
    /// - Throws: ``IngredientNormalizerError/blankName(text:)`` when `text` is
    ///   blank or whitespace-only (every blank entry would collide on `user_`).
    public static func createUserIngredient(
        _ text: String,
        category: IngredientCategory,
        buyFrom: BuyFrom,
        role: IngredientRole = .core
    ) throws(IngredientNormalizerError) -> Ingredient {
        let key = normalise(text)
        guard !key.isEmpty else { throw .blankName(text: text) }
        return Ingredient(
            id: "user_" + key.replacingSpaces(with: "_"),
            name: DartCompatibleText.trim(text),
            category: category,
            role: role,
            buyFrom: buyFrom,
            isUserCreated: true
        )
    }
}

extension String {
    /// Replaces every U+0020 scalar (not grapheme) with `replacement`, like
    /// Dart's `replaceAll(' ', ...)`.
    fileprivate func replacingSpaces(with replacement: Unicode.Scalar) -> String {
        var result = String.UnicodeScalarView()
        result.append(contentsOf: unicodeScalars.map { $0 == " " ? replacement : $0 })
        return String(result)
    }
}
