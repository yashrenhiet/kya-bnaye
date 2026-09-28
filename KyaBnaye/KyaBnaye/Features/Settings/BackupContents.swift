import Foundation
import KyaCore

extension BackupBundle {
    /// Everything in `snapshot`, in the same order, ready for ``KyaCore/BackupCodec``.
    init(_ snapshot: RepositorySnapshot) {
        self.init(
            seedVersion: snapshot.seedVersion, ingredients: snapshot.ingredients,
            pantryItems: snapshot.pantryItems, recipes: snapshot.recipes,
            mealLogs: snapshot.mealLogs, swipeEvents: snapshot.swipeEvents,
            shoppingItems: snapshot.shoppingItems)
    }

    /// The rows to hand to ``KyaCore/BackupRepository/replaceAll(with:)``, with the seed
    /// version the file was made at (`nil` for an older file that didn't record it).
    ///
    /// Recording the file's own version, not this phone's, is what lets the seed sync that
    /// follows a restore add exactly the seed rows the file predates; rows in the file are
    /// never overwritten by it.
    var snapshot: RepositorySnapshot {
        RepositorySnapshot(
            ingredients: ingredients, pantryItems: pantryItems, recipes: recipes,
            mealLogs: mealLogs, swipeEvents: swipeEvents, shoppingItems: shoppingItems,
            seedVersion: seedVersion)
    }

    /// How many rows of each kind the bundle holds.
    var summary: BackupSummary {
        BackupSummary(
            recipes: recipes.count, ingredients: ingredients.count,
            pantryItems: pantryItems.count, mealLogs: mealLogs.count,
            swipeEvents: swipeEvents.count, shoppingItems: shoppingItems.count)
    }
}

/// Row counts of a backup, for the export sheet and the import confirmation.
struct BackupSummary: Equatable, Sendable {
    let recipes: Int
    let ingredients: Int
    let pantryItems: Int
    let mealLogs: Int
    let swipeEvents: Int
    let shoppingItems: Int

    /// E.g. "80 recipes, 224 ingredients, 34 pantry items, 12 meals cooked, 150 swipes,
    /// 1 shopping item".
    var description: String {
        [
            Self.count(recipes, "recipe", "recipes"),
            Self.count(ingredients, "ingredient", "ingredients"),
            Self.count(pantryItems, "pantry item", "pantry items"),
            Self.count(mealLogs, "meal cooked", "meals cooked"),
            Self.count(swipeEvents, "swipe", "swipes"),
            Self.count(shoppingItems, "shopping item", "shopping items"),
        ].joined(separator: ", ")
    }

    private static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}

/// Why a backup file can't be restored. Every case leaves the data on this phone untouched.
enum BackupImportError: Error, Equatable, Sendable {
    /// The file couldn't be opened or read.
    case unreadableFile(detail: String)
    /// The file isn't a backup this app can read (see ``KyaCore/BackupFormatError``).
    case format(BackupFormatError)
    /// The file parsed, but its rows contradict each other (e.g. a recipe needs an
    /// ingredient the file doesn't contain), so restoring it would break the app.
    case inconsistent(detail: String)

    /// A plain-words explanation for the alert.
    var userMessage: String {
        switch self {
        case .unreadableFile:
            String(localized: "We couldn't open that file. Check it's downloaded, then try again.")
        case .format(.notAJSONObject):
            String(localized: "That file isn't a kya-bnaye backup.")
        case .format(.unsupportedVersion):
            String(
                localized:
                    "This backup was made by a newer version of kya-bnaye. Update the app, then try again."
            )
        case .format(.sectionNotAList), .format(.malformed), .inconsistent:
            String(localized: "This backup file is damaged or incomplete.")
        }
    }

    /// Developer-facing detail, shown in small print for bug reports.
    var detail: String {
        switch self {
        case .unreadableFile(let detail), .inconsistent(let detail): detail
        case .format(let error): error.message
        }
    }
}

/// Cross-row checks a decoded backup must pass before it may replace everything
/// (``KyaCore/BackupRepository/replaceAll(with:)`` does not check referential integrity).
enum BackupIntegrity {
    /// Checks that ingredient names and aliases don't collide and that every pantry record
    /// and recipe line names an ingredient in the file. Shopping rows may name unknown ids:
    /// the list shows them under "Other" and they restock nothing.
    ///
    /// - Parameter bundle: The decoded backup.
    /// - Throws: ``BackupImportError/inconsistent(detail:)`` naming the first problem.
    static func check(_ bundle: BackupBundle) throws(BackupImportError) {
        do {
            _ = try IngredientNormalizer(bundle.ingredients)
        } catch {
            throw .inconsistent(detail: error.description)
        }
        let known = Set(bundle.ingredients.map(\.id))
        if let item = bundle.pantryItems.first(where: { !known.contains($0.ingredientId) }) {
            throw .inconsistent(detail: "pantry item \(item.ingredientId) has no ingredient")
        }
        for recipe in bundle.recipes {
            if let line = recipe.ingredients.first(where: { !known.contains($0.ingredientId) }) {
                throw .inconsistent(
                    detail: "recipe \(recipe.id) needs unknown ingredient \(line.ingredientId)")
            }
        }
    }
}

/// The export file name, e.g. `kya-bnaye-backup-2026-09-27.json`, dated in `calendar`'s
/// time zone so it matches the user's "today".
///
/// - Parameters:
///   - date: The export instant.
///   - calendar: Defines the calendar day.
/// - Returns: The file name.
func backupFileName(for date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let day = String(
        format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    return "kya-bnaye-backup-\(day).json"
}
