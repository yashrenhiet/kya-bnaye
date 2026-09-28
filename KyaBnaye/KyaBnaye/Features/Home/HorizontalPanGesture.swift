import SwiftUI
import UIKit

extension View {
    /// Follows a drag that starts out horizontal, leaving vertical drags to the enclosing
    /// scroll view, for the swipe card inside Home's `ScrollView`.
    ///
    /// - Parameters:
    ///   - changed: Called as the finger moves, with the horizontal translation.
    ///   - ended: Called when the drag ends or is cancelled, with the horizontal translation
    ///     and velocity (points per second).
    /// - Returns: The view with the gesture attached.
    func horizontalPan(
        changed: @escaping (CGFloat) -> Void,
        ended: @escaping (_ translation: CGFloat, _ velocity: CGFloat) -> Void
    ) -> some View {
        modifier(HorizontalPanModifier(changed: changed, ended: ended))
    }
}

/// Uses ``HorizontalPanGesture`` where available (iOS 18+). On iOS 17 it falls back to a
/// simultaneous `DragGesture` that locks to the first direction of travel.
private struct HorizontalPanModifier: ViewModifier {
    let changed: (CGFloat) -> Void
    let ended: (CGFloat, CGFloat) -> Void

    @State private var axis: Axis?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(HorizontalPanGesture(changed: changed, ended: ended))
        } else {
            content.simultaneousGesture(fallbackDrag)
        }
    }

    private var fallbackDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let translation = value.translation
                if axis == nil {
                    axis =
                        abs(translation.width) > abs(translation.height) ? .horizontal : .vertical
                }
                guard axis == .horizontal else { return }
                changed(translation.width)
            }
            .onEnded { value in
                defer { axis = nil }
                guard axis == .horizontal else { return }
                let predicted = value.predictedEndTranslation.width
                ended(value.translation.width, (predicted - value.translation.width) * 4)
            }
    }
}

/// A pan that only ever starts horizontally.
///
/// On iOS 18 a SwiftUI `DragGesture` on the card, even as a simultaneous gesture, stops the
/// scroll view from scrolling when a vertical drag starts on the card, and the card fills
/// most of the screen. This recognizer declines to begin unless the pan is more horizontal
/// than vertical, so a vertical drag is left entirely to the scroll view.
@available(iOS 18.0, *)
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    let changed: (CGFloat) -> Void
    let ended: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer, context: Context
    ) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            changed(translation)
        case .ended, .cancelled, .failed:
            ended(translation, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    /// Lets the pan begin only when it moves more sideways than up or down.
    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
