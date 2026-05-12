import SwiftUI
import UIKit

// MARK: - Hide Keyboard Extension
public extension View {
    /// Hides the keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    /// Adds a tap gesture recognizer that dismisses keyboard when tapping anywhere
    /// This doesn't interfere with other controls like buttons or text fields
    func hideKeyboardOnTap() -> some View {
        self.background(KeyboardDismissView())
    }
}

// MARK: - UIViewRepresentable for Keyboard Dismiss
struct KeyboardDismissView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissUIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// Custom UIView that adds tap gesture to dismiss keyboard
class KeyboardDismissUIView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        // Find the window and add tap gesture
        if let window = self.window {
            // Remove any existing gesture recognizers we added
            window.gestureRecognizers?.removeAll { $0 is KeyboardDismissTapGesture }
            
            // Add new tap gesture
            let tapGesture = KeyboardDismissTapGesture(target: self, action: #selector(dismissKeyboard))
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = self
            window.addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// Custom tap gesture class to identify our gesture
class KeyboardDismissTapGesture: UITapGestureRecognizer {}

// MARK: - Gesture Delegate
extension KeyboardDismissUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow other gestures to work simultaneously
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't dismiss if touching the keyboard itself
        if let view = touch.view, view.isDescendant(of: UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController?.view ?? UIView()) {
            // Check if the touch is on a text input
            if touch.view is UITextField || touch.view is UITextView {
                return false
            }
        }
        return true
    }
}
