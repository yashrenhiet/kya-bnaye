import KyaCore

// The one place the app turns KyaCore enums into the words on screen. KyaCore's own
// `TagLabelled.label` is lower case (it doubles as a matching key), so it is title-cased here.

extension MealType {
    /// Title case display name, e.g. "Breakfast".
    var displayName: String {
        switch self {
        case .breakfast: String(localized: "Breakfast")
        case .lunch: String(localized: "Lunch")
        case .dinner: String(localized: "Dinner")
        case .snack: String(localized: "Snack")
        }
    }
}

extension DishBase {
    /// Display name for the base picker, e.g. "Roti".
    var displayName: String {
        switch self {
        case .rice: String(localized: "Rice")
        case .roti: String(localized: "Roti")
        case .bread: String(localized: "Bread")
        case .none: String(localized: "No base")
        }
    }
}

extension IngredientCategory {
    /// The section and picker title, e.g. "Grains & Atta".
    var displayName: String {
        switch self {
        case .sabzi: String(localized: "Sabzi")
        case .fruit: String(localized: "Fruits")
        case .dairy: String(localized: "Dairy")
        case .grains: String(localized: "Grains & Atta")
        case .dal: String(localized: "Dal & Pulses")
        case .masala: String(localized: "Masala")
        case .oilGhee: String(localized: "Oil & Ghee")
        case .packaged: String(localized: "Packaged")
        case .other: String(localized: "Other")
        }
    }
}

extension BuyFrom {
    /// Where an ingredient is bought, for pickers, Shopping sections and the shared list.
    var displayName: String {
        switch self {
        case .sabziwala: String(localized: "Sabziwala")
        case .kirana: String(localized: "Kirana")
        case .dairy: String(localized: "Dairy")
        case .other: String(localized: "Other")
        }
    }
}

extension TagLabelled {
    /// ``TagLabelled/label`` with its first letter capitalised, for chips and pickers.
    var displayName: String {
        label.prefix(1).uppercased() + label.dropFirst()
    }
}

extension Recipe {
    /// Meal types in the fixed breakfast → snack order, e.g. "Lunch / Dinner".
    var mealTypesText: String {
        MealType.allCases.filter(mealTypes.contains).map(\.displayName).joined(separator: " / ")
    }

    /// The tag names shown as chips on the detail screen, in a stable order.
    var tagDisplayNames: [String] {
        [tags.region.displayName, tags.dishType.displayName]
            + Flavour.allCases.filter(tags.flavours.contains).map(\.displayName)
            + [tags.heaviness.displayName, tags.protein.displayName]
    }
}
