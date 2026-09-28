import SwiftUI

// List and Form section titles and footnotes in the theme's secondary text colour. The
// system default (secondary label grey) is under 4.5:1 on the cream canvas.

/// A section title, read by VoiceOver as a heading.
struct SectionHeader: View {
    private let text: Text

    /// A localised title.
    init(_ title: LocalizedStringKey) { text = Text(title) }

    /// A title that is already user-facing (e.g. a category name).
    init(verbatim title: String) { text = Text(verbatim: title) }

    var body: some View {
        text
            .font(Typography.supporting.weight(.semibold))
            .foregroundStyle(ThemeColor.textSecondary.color)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A short explanation under a section.
struct SectionFooter: View {
    private let text: Text

    /// A localised footnote.
    init(_ note: LocalizedStringKey) { text = Text(note) }

    /// A footnote that is already user-facing.
    init(verbatim note: String) { text = Text(verbatim: note) }

    var body: some View {
        text
            .font(Typography.caption)
            .foregroundStyle(ThemeColor.textSecondary.color)
    }
}
