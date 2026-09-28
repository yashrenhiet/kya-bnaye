extension IngredientNormalizer {
    /// Autocomplete suggestions for a partly typed ingredient name, e.g. "alo"
    /// → Potato (via its alias "aloo") or "dah" → Curd (via "dahi").
    ///
    /// This only *proposes* ingredients for the user to pick; it never resolves
    /// text on its own. Resolution stays exact (``find(_:)``), so the "rice"
    /// never matches "rice flour" rule of `AGENTS.md` section 5.4 still holds.
    ///
    /// Ranking, best first: the exact name/alias match (``find(_:)``), then
    /// ingredients whose name starts with the typed key, then those with an
    /// alias starting with it, then those with any later word (of the name or
    /// an alias) starting with it. Ties are broken by normalised name, then id,
    /// so the order never depends on hashing.
    ///
    /// - Parameters:
    ///   - text: What the user typed so far; normalised with ``normalise(_:)``.
    ///   - limit: The maximum number of suggestions; `0` or less returns `[]`.
    ///   - isIncluded: Restricts the candidates (e.g. perishables only);
    ///     defaults to every catalog ingredient.
    /// - Returns: At most `limit` distinct ingredients; `[]` for blank text.
    public func suggestions(
        for text: String,
        limit: Int = 8,
        where isIncluded: (Ingredient) -> Bool = { _ in true }
    ) -> [Ingredient] {
        let key = Self.normalise(text)
        guard !key.isEmpty, limit > 0 else { return [] }
        let exactId = find(key)?.id
        let ranked = all.compactMap { ingredient -> (rank: Int, name: String, item: Ingredient)? in
            guard isIncluded(ingredient),
                let rank = matchRank(of: ingredient, key: key, exactId: exactId)
            else {
                return nil
            }
            return (rank, Self.normalise(ingredient.name), ingredient)
        }
        return
            ranked
            .sorted { ($0.rank, $0.name, $0.item.id) < ($1.rank, $1.name, $1.item.id) }
            .prefix(limit)
            .map(\.item)
    }

    /// How well `ingredient` matches `key` (lower is better), or `nil` for no
    /// match. `key` is already normalised and non-empty; `exactId` is the id
    /// ``find(_:)`` resolves it to, if any.
    private func matchRank(of ingredient: Ingredient, key: String, exactId: String?) -> Int? {
        if ingredient.id == exactId { return 0 }
        let name = Self.normalise(ingredient.name)
        if name.hasPrefix(key) { return 1 }
        let aliases = ingredient.aliases.map(Self.normalise)
        if aliases.contains(where: { $0.hasPrefix(key) }) { return 2 }
        let laterWords = ([name] + aliases).flatMap { $0.split(separator: " ").dropFirst() }
        if laterWords.contains(where: { $0.hasPrefix(key) }) { return 3 }
        return nil
    }
}
