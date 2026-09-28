/// How Home's swipe deck absorbs a rebuild without yanking the card the user is looking at.
///
/// The deck is rebuilt from scratch (``DeckBuilder``) whenever the data behind it changes,
/// for example the pantry after "Used up anything?" or a recipe edit. Replacing the cards
/// outright would swap the card under the user's finger mid-swipe, so the card on top is
/// pinned: it stays first (refreshed from the rebuild when the rebuild still offers it) and
/// only the cards behind it are replaced. Cards already swiped in this session never come
/// back.
public enum DeckRefresh {
    /// A new deck: `built` minus the excluded recipes, in the builder's order.
    ///
    /// - Parameters:
    ///   - built: The ``DeckBuilder`` output.
    ///   - excluded: Recipe ids not to show (already swiped this session, or already picked
    ///     today).
    /// - Returns: The cards to show, top card first.
    public static func fresh(
        _ built: [ScoredRecipe], excluding excluded: Set<String>
    ) -> [ScoredRecipe] {
        built.filter { !excluded.contains($0.recipe.id) }
    }

    /// Replaces the cards behind the top card with `rebuilt`, keeping the top card first.
    ///
    /// Postconditions: no recipe appears twice; no excluded recipe appears except a pinned
    /// top card; when `current` is empty the result equals ``fresh(_:excluding:)``.
    ///
    /// - Parameters:
    ///   - current: The cards on screen, top card first.
    ///   - rebuilt: The new ``DeckBuilder`` output for the changed data.
    ///   - excluded: Recipe ids not to show behind the top card.
    ///   - keepTop: Whether the top card may stay when `rebuilt` no longer offers it (for
    ///     example `false` once its recipe was deleted or hidden). It is always kept, in its
    ///     refreshed form, when `rebuilt` still offers it.
    /// - Returns: The cards to show, top card first.
    public static func refreshed(
        current: [ScoredRecipe],
        rebuilt: [ScoredRecipe],
        excluding excluded: Set<String>,
        keepingTopIf keepTop: (ScoredRecipe) -> Bool
    ) -> [ScoredRecipe] {
        guard let top = current.first else { return fresh(rebuilt, excluding: excluded) }
        let topId = top.recipe.id
        let behind = fresh(rebuilt, excluding: excluded.union([topId]))
        if let updated = rebuilt.first(where: { $0.recipe.id == topId }) {
            return [updated] + behind
        }
        return keepTop(top) ? [top] + behind : behind
    }
}
