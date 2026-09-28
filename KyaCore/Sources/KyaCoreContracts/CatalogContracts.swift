import Foundation
import KyaCore

private typealias F = Fixtures

extension RepositoryContracts {
    /// Every ``IngredientRepository`` check.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty repository.
    public static func ingredients(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<any IngredientRepository>] {
        let prefix = "IngredientRepository"
        return [
            ContractCheck("\(prefix): an empty catalog reads []") { repo in
                try expectIdentical(try await repo.all(), [], "all()")
            },
            ContractCheck("\(prefix): all() is sorted by id with every field kept") { repo in
                let user = F.ingredient("b_user", isUserCreated: true).withShelfLifeDays(nil)
                try await repo.upsert([F.ingredient("c"), user, F.ingredient("a")])
                try expectIdentical(
                    try await repo.all(), [F.ingredient("a"), user, F.ingredient("c")], "all()")
            },
            ContractCheck("\(prefix): upsert replaces every field of an existing id") { repo in
                try await repo.upsert([F.ingredient("a"), F.ingredient("b")])
                let edited = F.ingredient("a", name: "Edited")
                    .copy(aliases: [], role: .flavor, buyFrom: .kirana, isUserCreated: true)
                    .withShelfLifeDays(nil)
                try await repo.upsert([edited])
                try expectIdentical(try await repo.all(), [edited, F.ingredient("b")], "all()")
            },
            ContractCheck("\(prefix): upsert with a repeated id keeps the last one") { repo in
                let last = F.ingredient("a", name: "Last")
                try await repo.upsert([F.ingredient("a", name: "First"), last])
                try expectIdentical(try await repo.all(), [last], "all()")
            },
            ContractCheck("\(prefix): upsert([]) changes nothing") { repo in
                try await repo.upsert([F.ingredient("a")])
                try await repo.upsert([])
                try expectIdentical(try await repo.all(), [F.ingredient("a")], "all()")
            },
            ContractCheck("\(prefix): insertMissing never overwrites an existing row") { repo in
                let edited = F.ingredient("b", name: "User edit")
                try await repo.upsert([edited])
                let inserted = try await repo.insertMissing([
                    F.ingredient("c"), F.ingredient("b"), F.ingredient("a"),
                ])
                try expectEqual(inserted, ["a", "c"], "inserted ids")
                try expectIdentical(
                    try await repo.all(), [F.ingredient("a"), edited, F.ingredient("c")], "all()")
            },
            ContractCheck("\(prefix): insertMissing with a repeated id keeps the first") { repo in
                let first = F.ingredient("a", name: "First")
                let inserted = try await repo.insertMissing([first, F.ingredient("a", name: "2")])
                try expectEqual(inserted, ["a"], "inserted ids")
                try expectIdentical(try await repo.all(), [first], "all()")
            },
            ContractCheck("\(prefix): insertMissing of known ids inserts nothing") { repo in
                try await repo.upsert([F.ingredient("a")])
                try expectEqual(try await repo.insertMissing([F.ingredient("a")]), [], "ids")
                try expectEqual(try await repo.insertMissing([]), [], "ids for []")
            },
        ]
            + ObservationChecks.checks(
                prefix, timeout: streamTimeout,
                observe: { $0.watchAll() },
                write: { try await $0.upsert([F.ingredient("a")]) },
                isWritten: { $0.map(\.id) == ["a"] })
    }

    /// Every ``RecipeRepository`` check.
    ///
    /// - Parameter streamTimeout: How long to wait for each `watchAll()` element.
    /// - Returns: The checks, each to run against an empty repository.
    public static func recipes(
        streamTimeout: Duration = defaultStreamTimeout
    ) -> [ContractCheck<any RecipeRepository>] {
        recipeStorageChecks() + recipeFlagChecks()
            + ObservationChecks.checks(
                "RecipeRepository", timeout: streamTimeout,
                observe: { $0.watchAll() },
                write: { try await $0.upsert([F.recipe("a")]) },
                isWritten: { $0.map(\.id) == ["a"] })
    }

    private static func recipeStorageChecks() -> [ContractCheck<any RecipeRepository>] {
        let prefix = "RecipeRepository"
        return [
            ContractCheck("\(prefix): an empty book reads [] and finds nothing") { repo in
                try expectIdentical(try await repo.all(), [], "all()")
                try expect(try await repo.recipe(withId: "a") == nil, "recipe(withId:) found a")
            },
            ContractCheck("\(prefix): all() is sorted by id with every field kept") { repo in
                let plain = F.recipe("b").withImageAsset(nil).copy(
                    mealTypes: [.snack], base: DishBase.none, ingredients: [], steps: [],
                    source: .user, isFavorite: true, isHidden: true)
                try await repo.upsert([F.recipe("c"), plain, F.recipe("a")])
                try expectIdentical(
                    try await repo.all(), [F.recipe("a"), plain, F.recipe("c")], "all()")
            },
            ContractCheck("\(prefix): recipe(withId:) returns the stored recipe") { repo in
                try await repo.upsert([F.recipe("a"), F.recipe("b")])
                let found = try unwrap(try await repo.recipe(withId: "b"), "recipe(withId: b)")
                try expectIdentical([found], [F.recipe("b")], "recipe(withId: b)")
            },
            ContractCheck("\(prefix): upsert replaces every field of an existing id") { repo in
                try await repo.upsert([F.recipe("a")])
                let edited = F.recipe("a", name: "Edited").withImageAsset(nil).copy(
                    minutes: 45, steps: ["Only step"], source: .user, isFavorite: true)
                try await repo.upsert([edited])
                try expectIdentical(try await repo.all(), [edited], "all()")
            },
            ContractCheck("\(prefix): upsert with a repeated id keeps the last one") { repo in
                let last = F.recipe("a", name: "Last")
                try await repo.upsert([F.recipe("a", name: "First"), last])
                try expectIdentical(try await repo.all(), [last], "all()")
            },
            ContractCheck("\(prefix): insertMissing never overwrites an existing recipe") { repo in
                let edited = F.recipe("b", name: "User edit").copy(isFavorite: true)
                try await repo.upsert([edited])
                let inserted = try await repo.insertMissing([
                    F.recipe("c"), F.recipe("b"), F.recipe("a"),
                ])
                try expectEqual(inserted, ["a", "c"], "inserted ids")
                try expectIdentical(
                    try await repo.all(), [F.recipe("a"), edited, F.recipe("c")], "all()")
            },
            ContractCheck("\(prefix): insertMissing with a repeated id keeps the first") { repo in
                let first = F.recipe("a", name: "First")
                let inserted = try await repo.insertMissing([first, F.recipe("a", name: "2")])
                try expectEqual(inserted, ["a"], "inserted ids")
                try expectIdentical(try await repo.all(), [first], "all()")
            },
            ContractCheck("\(prefix): delete removes one recipe; unknown ids are ignored") { repo in
                try await repo.upsert([F.recipe("a"), F.recipe("b")])
                try await repo.delete(id: "a")
                try await repo.delete(id: "ghost")
                try expectIdentical(try await repo.all(), [F.recipe("b")], "all()")
                try expect(try await repo.recipe(withId: "a") == nil, "deleted recipe found")
            },
        ]
    }

    private static func recipeFlagChecks() -> [ContractCheck<any RecipeRepository>] {
        let prefix = "RecipeRepository"
        return [
            ContractCheck("\(prefix): setFavorite changes only isFavorite") { repo in
                try await repo.upsert([F.recipe("a"), F.recipe("b")])
                try await repo.setFavorite(true, forRecipeWithId: "a")
                try expectIdentical(
                    try await repo.all(), [F.recipe("a").copy(isFavorite: true), F.recipe("b")],
                    "after favouriting")
                try await repo.setFavorite(false, forRecipeWithId: "a")
                try expectIdentical(
                    try await repo.all(), [F.recipe("a"), F.recipe("b")], "after unfavouriting")
            },
            ContractCheck("\(prefix): setHidden changes only isHidden") { repo in
                try await repo.upsert([F.recipe("a").copy(isFavorite: true)])
                try await repo.setHidden(true, forRecipeWithId: "a")
                try expectIdentical(
                    try await repo.all(), [F.recipe("a").copy(isFavorite: true, isHidden: true)],
                    "after hiding")
                try await repo.setHidden(false, forRecipeWithId: "a")
                try expectIdentical(
                    try await repo.all(), [F.recipe("a").copy(isFavorite: true)], "after unhiding")
            },
            ContractCheck("\(prefix): flag setters throw notFound for an unknown id") { repo in
                try await expectError(RepositoryError.notFound("ghost"), "setFavorite") {
                    try await repo.setFavorite(true, forRecipeWithId: "ghost")
                }
                try await expectError(RepositoryError.notFound("ghost"), "setHidden") {
                    try await repo.setHidden(true, forRecipeWithId: "ghost")
                }
                try expectIdentical(try await repo.all(), [], "all()")
            },
        ]
    }
}
