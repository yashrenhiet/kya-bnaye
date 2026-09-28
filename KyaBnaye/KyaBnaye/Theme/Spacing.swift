import CoreGraphics

/// The spacing scale (4/8/12/16/24 pt). Use these instead of literal padding values.
enum Spacing {
    /// 4 pt: hairline gaps, e.g. between an icon and its caption.
    static let xSmall: CGFloat = 4
    /// 8 pt: related elements inside a group.
    static let small: CGFloat = 8
    /// 12 pt: rows and compact card padding.
    static let medium: CGFloat = 12
    /// 16 pt: standard screen margins and card padding.
    static let large: CGFloat = 16
    /// 24 pt: separation between sections.
    static let xLarge: CGFloat = 24
}

/// Corner radii for rounded shapes.
enum Radius {
    /// Chips and badges.
    static let small: CGFloat = 8
    /// Buttons and list cells.
    static let medium: CGFloat = 12
    /// Dish cards in the swipe deck.
    static let large: CGFloat = 20
}

/// Layout constants that come from accessibility requirements.
enum Metrics {
    /// Minimum tap target edge (WCAG 2.2 AA / Apple HIG).
    static let minimumTapTarget: CGFloat = 44
    /// Readable content width, so text lines stay short on larger screens.
    static let readableWidth: CGFloat = 480
}
