import Foundation

/// Latest-timestamp-per-recipe log that remembers first-seen order, so ties
/// sort deterministically (the Dart oracle relied on insertion-ordered maps
/// and a stable sort for this).
struct LikedLog {
    private var order: [String] = []
    private var latest: [String: Date] = [:]

    /// Keeps the later of the existing and new timestamp for `recipeId`.
    mutating func record(_ recipeId: String, at date: Date) {
        guard let current = latest[recipeId] else {
            order.append(recipeId)
            latest[recipeId] = date
            return
        }
        if date > current { latest[recipeId] = date }
    }

    /// Ids newest first; equal timestamps keep first-seen order.
    var idsNewestFirst: [String] {
        order.enumerated()
            .sorted { lhs, rhs in
                let left = latest[lhs.element] ?? .distantPast
                let right = latest[rhs.element] ?? .distantPast
                return left != right ? left > right : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

/// Cook-history precomputations for ``RankingContext``.
struct CookHistory {
    private(set) var lastCookedAt: [String: Date] = [:]
    private(set) var countInRutWindow: [String: Int] = [:]
    private(set) var lastBase: DishBase?

    init(
        mealLogs: [MealLog],
        recipesById: [String: Recipe],
        isInRutWindow: (Date) -> Bool
    ) {
        var mostRecentCookAt: Date?
        for log in mealLogs {
            if lastCookedAt[log.recipeId].map({ log.cookedAt > $0 }) ?? true {
                lastCookedAt[log.recipeId] = log.cookedAt
            }
            if isInRutWindow(log.cookedAt) {
                countInRutWindow[log.recipeId, default: 0] += 1
            }
            if mostRecentCookAt.map({ log.cookedAt > $0 }) ?? true {
                mostRecentCookAt = log.cookedAt
                lastBase = recipesById[log.recipeId]?.base
            }
        }
    }
}

/// Swipe-history precomputations for ``RankingContext``, over active events
/// only (see ``SwipeEvent/activeEvents(_:)``).
struct SwipeHistory {
    private(set) var lastLeftAt: [String: Date] = [:]
    private(set) var neverShown: Set<String> = []
    private(set) var likedAt = LikedLog()

    init(events: [SwipeEvent], isInLikeWindow: (Date) -> Bool) {
        for event in SwipeEvent.activeEvents(events) {
            switch event.action {
            case .left:
                if let current = lastLeftAt[event.recipeId], event.at <= current { continue }
                lastLeftAt[event.recipeId] = event.at
            case .neverShow:
                neverShown.insert(event.recipeId)
            case .right:
                if isInLikeWindow(event.at) { likedAt.record(event.recipeId, at: event.at) }
            case .undo:
                break
            }
        }
    }
}
