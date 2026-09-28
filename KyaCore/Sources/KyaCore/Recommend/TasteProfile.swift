import Foundation

/// A household's learned taste: an affinity score per ``TagKey``, e.g. "how
/// much do they seem to like spicy food lately".
///
/// **Always derived, never persisted** (ADR 008): build it with
/// ``from(events:mealLogs:recipesById:now:config:)`` from the full history
/// each time a deck is built, so "reset my taste" and formula fixes apply
/// retroactively for free.
public struct TasteProfile: Sendable, Hashable {
    /// Raw decay-weighted sum of signed signal weights per tag. Unbounded; see
    /// ``normalised(_:)`` for the squashed value.
    public let affinity: [TagKey: Double]

    /// Sum of unsigned decay-weighted signal weights per tag: how much evidence
    /// exists either way. The deck builder uses it to find under-explored tags
    /// rather than disliked ones.
    public let evidence: [TagKey: Double]

    /// The configuration the profile was folded with (it supplies the
    /// normalisation divisor).
    public let config: ScoringConfig

    /// Creates a profile from precomputed maps.
    ///
    /// - Parameters:
    ///   - affinity: Signed affinity per tag.
    ///   - evidence: Unsigned evidence per tag.
    ///   - config: Supplies ``ScoringConfig/tasteNormaliseDivisor``.
    public init(affinity: [TagKey: Double], evidence: [TagKey: Double], config: ScoringConfig) {
        self.affinity = affinity
        self.evidence = evidence
        self.config = config
    }

    /// ``affinity`` squashed to (-1, 1) via `tanh(affinity / divisor)`
    /// (`docs/design/RECOMMENDER.md` section 4). A tag with no evidence reads
    /// as a neutral `0`. Saturates to ±1 instead of producing NaN.
    ///
    /// - Parameter key: The tag to look up.
    /// - Returns: A value in `[-1, 1]`.
    public func normalised(_ key: TagKey) -> Double {
        Self.stableTanh((affinity[key] ?? 0) / config.tasteNormaliseDivisor)
    }

    /// The evidence recorded for `key`, or `0` if none.
    ///
    /// - Parameter key: The tag to look up.
    /// - Returns: The unsigned evidence sum.
    public func evidence(for key: TagKey) -> Double {
        evidence[key] ?? 0
    }

    /// Numerically stable `tanh`: `exp(-2|x|)` lies in (0, 1] so it never
    /// overflows; the sign is restored afterwards.
    private static func stableTanh(_ x: Double) -> Double {
        let e = exp(-2 * abs(x))
        let sign: Double = x > 0 ? 1 : (x < 0 ? -1 : 0)
        return sign * (1 - e) / (1 + e)
    }

    /// Folds `events` and `mealLogs` into a profile as of `now`.
    ///
    /// Active swipes (see ``SwipeEvent/activeEvents(_:)``) contribute their
    /// signal weight, then every meal log contributes the cooked weight, each
    /// decayed with a ``ScoringConfig/tasteDecayHalfLifeDays`` half-life over
    /// whole elapsed hours. Future-dated signals count at full weight, never
    /// amplified. Signals for recipes missing from `recipesById` (deleted) are
    /// skipped. Onboarding picks are plain right swipes.
    ///
    /// - Parameters:
    ///   - events: The full swipe log, including undo events.
    ///   - mealLogs: Every cooked meal.
    ///   - recipesById: Recipe lookup for tags.
    ///   - now: The reference instant.
    ///   - config: Signal weights and decay settings.
    /// - Returns: The derived profile.
    public static func from(
        events: [SwipeEvent],
        mealLogs: [MealLog],
        recipesById: [String: Recipe],
        now: Date,
        config: ScoringConfig = ScoringConfig()
    ) -> TasteProfile {
        var affinity: [TagKey: Double] = [:]
        var evidence: [TagKey: Double] = [:]

        func fold(_ recipeId: String, _ weight: Double, _ at: Date) {
            guard let recipe = recipesById[recipeId] else { return }
            let decayed =
                weight * decay(at: at, now: now, halfLifeDays: config.tasteDecayHalfLifeDays)
            for key in recipe.tags.allKeys {
                affinity[key, default: 0] += decayed
                evidence[key, default: 0] += abs(decayed)
            }
        }

        for event in SwipeEvent.activeEvents(events) {
            switch event.action {
            case .right: fold(event.recipeId, config.signalWeightRightSwipe, event.at)
            case .left: fold(event.recipeId, config.signalWeightLeftSwipe, event.at)
            case .neverShow: fold(event.recipeId, config.signalWeightNeverShow, event.at)
            case .undo: break
            }
        }
        for log in mealLogs {
            fold(log.recipeId, config.signalWeightCooked, log.cookedAt)
        }
        return TasteProfile(affinity: affinity, evidence: evidence, config: config)
    }

    /// `0.5 ^ (ageDays / halfLife)`, where `ageDays` is whole elapsed hours / 24
    /// (the Dart oracle's `inHours / 24.0`). Decay is defined on elapsed time,
    /// not calendar days.
    private static func decay(at: Date, now: Date, halfLifeDays: Int) -> Double {
        let elapsedHours = (now.timeIntervalSince(at) / 3600).rounded(.towardZero)
        let ageDays = elapsedHours / 24
        if ageDays <= 0 { return 1 }
        return pow(0.5, ageDays / Double(halfLifeDays))
    }

    /// The weighted mean of this profile's normalised affinity across every tag
    /// dimension of `tags` (`docs/design/RECOMMENDER.md` section 4, "Craving
    /// score"). Shared by both rankers so "how much does this household's taste
    /// favour this dish" has one definition.
    ///
    /// Flavours are averaged in ``Flavour`` declaration order; a dish with no
    /// flavours treats the flavour dimension as neutral.
    ///
    /// - Parameters:
    ///   - tags: The dish's tags.
    ///   - config: Supplies the per-dimension weights.
    /// - Returns: A value in `[-1, 1]` when the weights sum to 1.
    public func tasteScore(for tags: DishTags, config: ScoringConfig) -> Double {
        let flavours = Flavour.allCases.filter(tags.flavours.contains)
        let flavourMean =
            flavours.isEmpty
            ? 0
            : flavours.map { normalised($0.tagKey) }.reduce(0, +) / Double(flavours.count)
        return config.taggedRegionWeight * normalised(tags.region.tagKey)
            + config.taggedDishTypeWeight * normalised(tags.dishType.tagKey)
            + config.taggedFlavourWeight * flavourMean
            + config.taggedHeavinessWeight * normalised(tags.heaviness.tagKey)
            + config.taggedProteinWeight * normalised(tags.protein.tagKey)
    }
}
