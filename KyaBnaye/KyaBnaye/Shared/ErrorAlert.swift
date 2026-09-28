import SwiftUI

extension View {
    /// Shows `message` in an alert with a single OK button while it is non-nil, and clears
    /// it when the alert is dismissed. For actions that failed; the screen stays usable.
    ///
    /// - Parameters:
    ///   - message: The plain-language failure, or `nil` when there is none.
    ///   - title: The alert title.
    /// - Returns: The view with the alert attached.
    func errorAlert(
        _ message: Binding<String?>, title: LocalizedStringKey = "Something went wrong"
    ) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { text in
            Text(verbatim: text)
        }
    }
}
