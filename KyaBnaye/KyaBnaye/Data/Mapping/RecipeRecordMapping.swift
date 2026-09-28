import Foundation
import KyaCore

/// The stored form of one ``KyaCore/RecipeIngredient`` inside
/// `RecipeRecord.ingredientLines`. Its JSON keys are part of the persisted format: rename
/// or remove one only in a new schema version with a custom migration stage. New fields
/// must be optional so rows written earlier still decode.
struct StoredRecipeLine: Codable, Equatable, Sendable {
    /// Canonical ingredient id.
    let ingredientId: String
    /// Free-text amount, e.g. "2 katori".
    let quantityText: String
    /// Whether the dish works without it.
    let isOptional: Bool
}

extension RecipeRecord: DomainRecord {
    static let entityName = "Recipe"

    static func rowKey(of row: Recipe) -> String { row.id }

    var rowKey: String { id }

    convenience init(rowKey: String) {
        self.init(id: rowKey)
    }

    func update(from row: Recipe) throws(DataStoreError) {
        let lines = row.ingredients.map {
            StoredRecipeLine(
                ingredientId: $0.ingredientId, quantityText: $0.quantityText,
                isOptional: $0.isOptional)
        }
        do {
            ingredientLines = try JSONEncoder().encode(lines)
        } catch {
            throw mappingFailure("ingredients")
        }
        name = row.name
        mealTypesRaw = sortedRawValues(row.mealTypes)
        minutes = row.minutes
        baseRaw = row.base.rawValue
        steps = row.steps
        regionRaw = row.tags.region.rawValue
        dishTypeRaw = row.tags.dishType.rawValue
        flavoursRaw = sortedRawValues(row.tags.flavours)
        heavinessRaw = row.tags.heaviness.rawValue
        proteinRaw = row.tags.protein.rawValue
        imageAsset = row.imageAsset
        isFavorite = row.isFavorite
        isHidden = row.isHidden
        sourceRaw = row.source.rawValue
    }

    func toRow() throws(DataStoreError) -> Recipe {
        let lines: [StoredRecipeLine]
        do {
            lines = try JSONDecoder().decode([StoredRecipeLine].self, from: ingredientLines)
        } catch {
            throw mappingFailure("ingredients")
        }
        let tags = DishTags(
            region: try decode(regionRaw, field: "tags.region"),
            dishType: try decode(dishTypeRaw, field: "tags.dishType"),
            flavours: try decodeSet(flavoursRaw, field: "tags.flavours"),
            heaviness: try decode(heavinessRaw, field: "tags.heaviness"),
            protein: try decode(proteinRaw, field: "tags.protein"))
        return Recipe(
            id: id,
            name: name,
            mealTypes: try decodeSet(mealTypesRaw, field: "mealTypes"),
            minutes: minutes,
            base: try decode(baseRaw, field: "base"),
            ingredients: lines.map {
                RecipeIngredient(
                    ingredientId: $0.ingredientId, quantityText: $0.quantityText,
                    isOptional: $0.isOptional)
            },
            steps: steps,
            tags: tags,
            source: try decode(sourceRaw, field: "source"),
            imageAsset: imageAsset,
            isFavorite: isFavorite,
            isHidden: isHidden)
    }
}
