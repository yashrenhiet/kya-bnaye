import SwiftUI

extension View {
    /// Fills the available space and paints the themed canvas behind the content,
    /// extending under the safe areas.
    func themedScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ThemeColor.background.color.ignoresSafeArea())
    }
}
