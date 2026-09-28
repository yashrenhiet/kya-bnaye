import KyaCore

/// The 13 everyday fixture recipes from
/// `legacy/packages/kya_core/test/recommend/rankers/fixtures.dart`.
/// Required-ingredient order matters: it is the order "Missing: ..."
/// explanations list them in.
enum RankerRecipes {
    private static let lunchDinner: Set<MealType> = [.lunch, .dinner]

    private static func make(
        _ id: String,
        _ name: String,
        meals: Set<MealType> = lunchDinner,
        minutes: Int,
        base: DishBase,
        required: [String],
        optional: [String] = [],
        tags: DishTags
    ) -> Recipe {
        let lines =
            required.map { RecipeIngredient(ingredientId: $0, quantityText: "as needed") }
            + optional.map {
                RecipeIngredient(ingredientId: $0, quantityText: "to garnish", isOptional: true)
            }
        return Recipe(
            id: id, name: name, mealTypes: meals, minutes: minutes, base: base, ingredients: lines,
            steps: ["Cook it the way ghar pe banta hai."], tags: tags, source: .seed)
    }

    private static func tags(
        _ region: Region,
        _ dishType: DishType,
        _ flavours: Set<Flavour>,
        _ heaviness: Heaviness,
        _ protein: Protein
    ) -> DishTags {
        DishTags(
            region: region, dishType: dishType, flavours: flavours, heaviness: heaviness,
            protein: protein)
    }

    static let all: [Recipe] = [
        make(
            "aloo_matar", "Aloo Matar", minutes: 30, base: .roti,
            required: ["potato", "matar", "onion", "tomato", "salt", "oil", "haldi"],
            optional: ["coriander"],
            tags: tags(.north, .curry, [.spicy, .savoury], .medium, .vegOnly)),
        make(
            "palak_paneer", "Palak Paneer", minutes: 35, base: .roti,
            required: [
                "palak", "paneer", "onion", "ginger_garlic", "kasuri_methi", "salt", "oil",
            ],
            optional: ["cream"], tags: tags(.north, .curry, [.savoury, .mild], .medium, .paneer)),
        make(
            "dal_tadka", "Dal Tadka", minutes: 30, base: .none,
            required: ["toor_dal", "onion", "tomato", "jeera", "haldi", "salt", "oil"],
            optional: ["coriander"],
            tags: tags(.north, .dal, [.savoury, .spicy], .light, .dalLegume)),
        make(
            "jeera_rice", "Jeera Rice", minutes: 20, base: .rice,
            required: ["rice", "jeera", "oil", "salt"],
            tags: tags(.north, .rice, [.savoury, .mild], .light, .vegOnly)),
        make(
            "rajma_chawal", "Rajma Chawal", minutes: 60, base: .rice,
            required: [
                "rajma", "rice", "onion", "tomato", "ginger_garlic", "garam_masala", "salt", "oil",
            ],
            tags: tags(.punjabi, .curry, [.spicy, .savoury], .heavy, .dalLegume)),
        make(
            "chole_bhature", "Chole Bhature", minutes: 50, base: .bread,
            required: [
                "chana", "onion", "tomato", "ginger_garlic", "garam_masala", "salt", "oil",
            ],
            tags: tags(.punjabi, .curry, [.spicy, .tangy], .heavy, .dalLegume)),
        make(
            "masala_dosa", "Masala Dosa", meals: [.breakfast, .lunch], minutes: 40, base: .none,
            required: [
                "dosa_batter", "potato", "onion", "green_chilli", "curry_leaves", "salt", "oil",
            ],
            tags: tags(.south, .breakfast, [.savoury, .spicy], .medium, .vegOnly)),
        make(
            "lemon_rice", "Lemon Rice", minutes: 20, base: .rice,
            required: ["rice", "lemon", "curry_leaves", "haldi", "salt", "oil"],
            tags: tags(.south, .rice, [.tangy, .savoury], .light, .vegOnly)),
        make(
            "poha", "Kanda Poha", meals: [.breakfast, .snack], minutes: 15, base: .none,
            required: ["poha", "onion", "green_chilli", "haldi", "salt", "oil"],
            optional: ["lemon", "coriander"],
            tags: tags(.west, .breakfast, [.savoury, .mild], .light, .vegOnly)),
        make(
            "upma", "Upma", meals: [.breakfast], minutes: 20, base: .none,
            required: ["rava", "onion", "green_chilli", "curry_leaves", "salt", "oil"],
            tags: tags(.south, .breakfast, [.savoury, .mild], .light, .vegOnly)),
        make(
            "egg_curry", "Egg Curry", minutes: 35, base: .rice,
            required: [
                "egg", "onion", "tomato", "ginger_garlic", "garam_masala", "haldi", "salt", "oil",
            ],
            tags: tags(.east, .curry, [.spicy, .savoury], .medium, .egg)),
        make(
            "dhokla", "Khaman Dhokla", meals: [.breakfast, .snack], minutes: 30, base: .none,
            required: ["besan", "curd", "lemon", "green_chilli", "salt", "oil"],
            tags: tags(.gujarati, .snack, [.sweet, .tangy], .light, .vegOnly)),
        make(
            "veg_hakka_noodles", "Veg Hakka Noodles", meals: [.dinner, .snack], minutes: 25,
            base: .none,
            required: ["noodles", "cabbage", "soy_sauce", "ginger_garlic", "oil", "salt"],
            tags: tags(.indoChinese, .onePot, [.spicy, .savoury], .medium, .vegOnly)),
    ]
}
