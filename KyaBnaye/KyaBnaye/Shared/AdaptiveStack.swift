import SwiftUI

/// A row that is horizontal at normal text sizes and stacks vertically (leading-aligned)
/// at accessibility sizes, so long names keep the full width instead of wrapping one
/// letter per line.
///
/// The content closure receives whether the row is stacked, e.g. to drop a `Spacer`.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = Spacing.medium
    var alignment: VerticalAlignment = .center
    @ViewBuilder let content: (_ isStacked: Bool) -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout =
            isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        layout { content(isStacked) }
    }
}
