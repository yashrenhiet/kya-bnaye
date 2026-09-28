import SwiftUI

/// Semantic text styles. All scale with Dynamic Type; never use fixed point sizes.
///
/// Headlines use the serif design for a cookbook feel; reading text stays in the default
/// design so body copy is as legible as possible.
enum Typography {
    /// The single most prominent line on a card, e.g. a dish name.
    static let display = Font.system(.largeTitle, design: .serif, weight: .bold)
    /// Section or empty-state headline.
    static let headline = Font.system(.title2, design: .serif, weight: .semibold)
    /// Default reading text.
    static let body = Font.body
    /// Supporting text, e.g. a recommendation reason.
    static let supporting = Font.subheadline
    /// Small metadata such as cooking time or expiry.
    static let caption = Font.caption
}
