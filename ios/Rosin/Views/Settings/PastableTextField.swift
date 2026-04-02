import SwiftUI
import UIKit

/// A UIKit-backed text field that guarantees paste always works.
/// Uses a custom UITextField subclass that explicitly allows paste
/// in canPerformAction and becomes first responder on appear.
struct PastableTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> AlwaysPastableField {
        let field = AlwaysPastableField()
        field.placeholder = placeholder
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        field.borderStyle = .roundedRect
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.clearButtonMode = .whileEditing
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        // Become first responder after a brief delay so the view is in the hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            field.becomeFirstResponder()
        }
        return field
    }

    func updateUIView(_ uiView: AlwaysPastableField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

/// UITextField subclass that explicitly allows all edit actions including paste.
/// Overrides canPerformAction to never block paste, even when the system
/// would otherwise disable it due to content type or keyboard restrictions.
class AlwaysPastableField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    // Override paste directly to read from UIPasteboard without restrictions
    override func paste(_ sender: Any?) {
        if let string = UIPasteboard.general.string {
            // Insert at cursor position or replace selection
            if let range = selectedTextRange {
                replace(range, withText: string.trimmingCharacters(in: .whitespacesAndNewlines))
                sendActions(for: .editingChanged)
            } else {
                text = (text ?? "") + string.trimmingCharacters(in: .whitespacesAndNewlines)
                sendActions(for: .editingChanged)
            }
        }
    }
}
