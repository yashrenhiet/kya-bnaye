/// Rule I3 for ``SeedValidator``: every normalised name or alias maps to one
/// ingredient, and no alias repeats within an ingredient or equals its own
/// name. Internal.
///
/// Keys use ``IngredientNormalizer/normalise(_:)``, the exact rule runtime
/// lookup applies, so a catalogue that passes I3 always builds a normalizer.
/// Swift compares keys up to Unicode canonical equivalence (the Dart oracle
/// compared code units), which is stricter and matches runtime lookup.
enum SeedAliasCollisions {
    /// The I3 issues in `ingredients`: per-ingredient alias problems in
    /// catalogue order, then one issue per colliding key in the order each key
    /// was first seen. A key only collides when at least one side is an alias;
    /// name-versus-name clashes are reported by I2.
    static func issues(_ ingredients: [Ingredient]) -> [SeedIssue] {
        var issues: [SeedIssue] = []
        var keyOrder: [String] = []
        // Normalised key -> owning ingredient id -> contributed by an alias.
        var owners: [String: [String: Bool]] = [:]
        func claim(_ key: String, _ id: String, viaAlias: Bool) {
            if owners[key] == nil { keyOrder.append(key) }
            owners[key, default: [:]][id, default: false] = owners[key]?[id] == true || viaAlias
        }

        for ingredient in ingredients {
            let nameKey = IngredientNormalizer.normalise(ingredient.name)
            var own = Set<String>()
            if !nameKey.isEmpty { claim(nameKey, ingredient.id, viaAlias: false) }
            for (index, alias) in ingredient.aliases.enumerated() {
                let key = IngredientNormalizer.normalise(alias)
                if key.isEmpty { continue }  // I4 reports blank aliases.
                let location = "ingredients[\(ingredient.id)].aliases[\(index)]"
                if key == nameKey {
                    issues.append(
                        SeedIssue(
                            .i3AliasCollision, location,
                            "alias \"\(key)\" repeats the ingredient name"))
                } else if !own.insert(key).inserted {
                    issues.append(
                        SeedIssue(.i3AliasCollision, location, "alias \"\(key)\" is listed twice"))
                } else {
                    claim(key, ingredient.id, viaAlias: true)
                }
            }
        }
        for key in keyOrder {
            guard let byId = owners[key], byId.count > 1, byId.values.contains(true) else {
                continue
            }
            let ids = byId.keys.sorted(by: SeedJSONObject.precedes)
            issues.append(
                SeedIssue(
                    .i3AliasCollision, "ingredients",
                    "\"\(key)\" resolves to more than one ingredient: "
                        + ids.joined(separator: ", ")))
        }
        return issues
    }
}
