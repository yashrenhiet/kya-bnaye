import KyaCore
import SwiftUI

/// History: meals you've cooked, grouped by date, pushed from Home.
struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: HistoryStore?

    var body: some View {
        Group {
            if let store {
                HistoryScreen(store: store)
            } else {
                ProgressView()
                    .accessibilityLabel("Loading your history")
            }
        }
        .themedScreen()
        .navigationTitle("History")
        .task {
            guard store == nil, let repositories = environment.repositories else { return }
            store = HistoryStore(
                repositories: repositories, now: environment.now,
                calendar: { [environment] in environment.calendar })
        }
    }
}

/// The history list for a ready store.
private struct HistoryScreen: View {
    let store: HistoryStore
    @State private var reloadToken = 0

    var body: some View {
        content
            .task(id: reloadToken) { await store.observe() }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView("Loading your history…")
                .font(Typography.body)
        case .failed(let message):
            LoadFailedView(title: "Couldn't load your history", detail: message) {
                reloadToken += 1
            }
        case .loaded:
            let sections = store.sections
            if sections.isEmpty {
                CenteredScrollView {
                    EmptyStateView(
                        symbolName: "clock.arrow.circlepath",
                        title: "Nothing cooked yet",
                        message:
                            "Tap “I made this” on a dish and it shows up here, so the deck can avoid repeats."
                    )
                }
            } else {
                HistoryList(sections: sections)
            }
        }
    }
}

/// Date sections ("Today", "Yesterday", "Thursday, 24 Sep · 3 days ago") with meal rows.
private struct HistoryList: View {
    let sections: [HistorySection]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        HistoryRow(entry: entry)
                    }
                } header: {
                    SectionHeader(verbatim: section.title)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// One cooked meal: artwork, dish name, meal slot and time.
private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: Spacing.medium) {
            RecipeArtwork(
                recipeId: entry.recipeId, name: entry.recipeName, cornerRadius: Radius.small
            )
            .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(entry.recipeName)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(ThemeColor.textPrimary.color)
                Text("\(entry.mealType.displayName) · \(entry.timeText)")
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
        }
        .frame(minHeight: Metrics.minimumTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.entry")
    }
}
