import SwiftUI

/// The placeholder photo for a dish until real food photography lands (every seed
/// `imageAsset` is `nil` in v1): a warm gradient with the dish's initial.
///
/// The palette is picked deterministically from the recipe id (a stable FNV-1a hash, never
/// `hashValue`, which is seeded per process), so a dish always looks the same in the recipe
/// book, the swipe deck and Today's picks. Every colour is a theme token. The artwork is
/// decorative: it is hidden from VoiceOver because the dish name is always shown next to it.
struct RecipeArtwork: View {
    /// The recipe id; decides the palette.
    let recipeId: String
    /// The dish name; its first letter is drawn.
    let name: String
    /// Corner radius of the artwork.
    var cornerRadius: CGFloat = Radius.large

    var body: some View {
        let palette = Self.palette(for: recipeId)
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [palette.start.color, palette.end.color],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(ThemeColor.turmeric.color.opacity(0.25))
                    .frame(width: side * 0.9, height: side * 0.9)
                    .offset(x: proxy.size.width * 0.3, y: -proxy.size.height * 0.25)
                // The initial is part of the graphic, so it scales with the frame rather than
                // with Dynamic Type; the readable dish name is always shown elsewhere.
                Text(Self.initial(of: name))
                    .font(.system(size: max(side * 0.45, 1), weight: .bold, design: .serif))
                    .foregroundStyle(ThemeColor.onAccent.color.opacity(0.92))
                    .shadow(color: ThemeColor.textPrimary.color.opacity(0.25), radius: side * 0.02)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    /// A gradient pair of theme tokens.
    struct Palette: Equatable {
        /// Top-leading colour.
        let start: ThemeColor
        /// Bottom-trailing colour.
        let end: ThemeColor
    }

    /// The warm palettes the artwork rotates through.
    static let palettes: [Palette] = [
        Palette(start: .accent, end: .turmeric),
        Palette(start: .swipeNever, end: .accent),
        Palette(start: .stockPlenty, end: .turmeric),
        Palette(start: .stockLow, end: .accent),
        Palette(start: .accent, end: .stockOut),
        Palette(start: .swipeWant, end: .stockLow),
    ]

    /// The palette for `recipeId`; the same id always gets the same palette.
    ///
    /// - Parameter recipeId: The recipe id.
    /// - Returns: One of ``palettes``.
    static func palette(for recipeId: String) -> Palette {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in recipeId.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return palettes[Int(hash % UInt64(palettes.count))]
    }

    /// The upper-cased first character of `name`, or a bowl-like dot for a blank name.
    ///
    /// - Parameter name: The dish name.
    /// - Returns: A one-character string.
    static func initial(of name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() }
            ?? "•"
    }
}

#Preview {
    HStack(spacing: Spacing.medium) {
        RecipeArtwork(recipeId: "dal_tadka", name: "Dal Tadka")
        RecipeArtwork(recipeId: "poha", name: "Poha", cornerRadius: Radius.small)
            .frame(width: 56, height: 56)
    }
    .frame(height: 180)
    .padding()
}
