import SwiftUI
import UIKit

// ── APIKeyTextField ─────────────────────────────────────────────────
// UIKit-backed text field for API key entry. Guarantees paste works
// around the iOS 26.x Simulator pasteboard sync bug. Also respects
// SwiftUI layout constraints so it doesn't overflow parent bounds.

typealias APIKeyTextField = PastableTextField

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
        field.isSecureTextEntry = false
        field.clipsToBounds = true
        // Critical: tell Auto Layout this field should shrink to fit, not expand
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        // Auto-focus after the view settles into the hierarchy
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

/// UITextField subclass that guarantees paste is never blocked.
class AlwaysPastableField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        guard let string = UIPasteboard.general.string else { return }
        let cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = selectedTextRange {
            replace(range, withText: cleaned)
        } else {
            text = (text ?? "") + cleaned
        }
        sendActions(for: .editingChanged)
    }

    // Respect SwiftUI's proposed width
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 36)
    }
}
