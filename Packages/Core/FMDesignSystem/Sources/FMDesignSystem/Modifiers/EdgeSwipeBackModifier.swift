import SwiftUI

/// Android-style edge-swipe-to-go-back: dragging right starting from a strip near
/// the leading edge triggers `action`.
///
/// Needed on screens that hide the system back button or nav bar
/// (`.navigationBarBackButtonHidden(true)` / `.toolbar(.hidden, for: .navigationBar)`),
/// since both disable iOS's own interactive pop (swipe-to-go-back) gesture as a
/// side effect — this restores equivalent behavior manually.
///
/// The gesture lives on a narrow transparent strip overlaid on just the leading
/// edge, not on the whole content: attaching a plain `.gesture()` to a container
/// that wraps a `ScrollView` never fires, because the `ScrollView`'s own pan
/// recognizer (a descendant) claims the touch first. Scoping it to an edge strip
/// avoids competing with scrolling anywhere else on screen.
public struct EdgeSwipeBackModifier: ViewModifier {
    let action: () -> Void

    /// Width of the leading strip that recognizes the swipe.
    private let edgeWidth: CGFloat = 20
    /// Minimum horizontal drag distance before the gesture fires.
    private let minTranslation: CGFloat = 60

    public func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            Color.clear
                .frame(width: edgeWidth)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            guard value.translation.width >= minTranslation,
                                  abs(value.translation.height) < value.translation.width else { return }
                            action()
                        }
                )
        }
    }
}

public extension View {
    /// See `EdgeSwipeBackModifier`.
    func edgeSwipeToGoBack(action: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeBackModifier(action: action))
    }
}
