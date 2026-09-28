import KyaCore
import SwiftUI

/// The filter chips: Cookable now, Quick, Favourite and a Meal menu. A selected chip shows a
/// checkmark and a filled background, so selection never relies on colour alone.
///
/// One scrolling row normally; at accessibility text sizes the chips wrap instead, so no
/// chip is wider than the screen.
struct RecipeFilterBar: View {
    @Binding var filter: RecipeFilter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            FlowLayout { chips }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.small)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.small) { chips }
                    .padding(.horizontal, Spacing.large)
                    .padding(.vertical, Spacing.small)
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        chip(String(localized: "Cookable now"), symbol: "frying.pan", $filter.cookableNow)
        chip(
            String(localized: "Quick (≤\(RecipeFilter.quickMaxMinutes) min)"),
            symbol: "timer", $filter.quick)
        chip(String(localized: "Favourite"), symbol: "heart", $filter.favouritesOnly)
        mealMenu
    }

    private var mealMenu: some View {
        Menu {
            Picker("Meal", selection: $filter.mealType) {
                Text("Any meal").tag(MealType?.none)
                ForEach(MealType.allCases, id: \.self) { meal in
                    Text(meal.displayName).tag(MealType?.some(meal))
                }
            }
        } label: {
            ChipLabel(
                title: filter.mealType?.displayName ?? String(localized: "Meal"),
                symbolName: "clock", isOn: filter.mealType != nil, showsDisclosure: true)
        }
        .accessibilityLabel("Meal")
        .accessibilityValue(filter.mealType?.displayName ?? String(localized: "Any meal"))
        .accessibilityIdentifier("recipes.filter.meal")
    }

    private func chip(_ title: String, symbol: String, _ isOn: Binding<Bool>) -> some View {
        SelectableChip(
            title: title, symbolName: symbol, isOn: isOn.wrappedValue,
            hint: isOn.wrappedValue
                ? String(localized: "Removes this filter.")
                : String(localized: "Shows only matching dishes.")
        ) {
            isOn.wrappedValue.toggle()
        }
    }
}
