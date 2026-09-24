import SwiftUI
import UIKit

/// TS-01 containing app: setup steps plus a test bench of text fields covering each
/// keyboard type the extension adapts to.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("التفعيل · Setup") {
                    SetupStep(number: 1, text: "Settings › General › Keyboard › Keyboards › Add New Keyboard… › BKeyboard")
                    // UX spec §41: never imply typing needs Full Access.
                    SetupStep(number: 2, text: "Core typing works without Full Access. Full Access enables shared personal dictionary, snippets and clipboard features.")
                    Button("Open BKeyboard Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("Test bench") {
                    TestField(title: "Default · نص عادي", keyboard: .default, returnKey: .default)
                    TestField(title: "Email", keyboard: .emailAddress, returnKey: .next, capitalization: .never)
                    TestField(title: "URL", keyboard: .URL, returnKey: .go, capitalization: .never)
                    TestField(title: "Web search", keyboard: .webSearch, returnKey: .search)
                    TestField(title: "Number pad", keyboard: .numberPad, returnKey: .done)
                    TestField(title: "Decimal pad", keyboard: .decimalPad, returnKey: .done)
                    TestField(title: "Send", keyboard: .default, returnKey: .send)
                    SecureField("Secure field (should fall back to system keyboard)", text: .constant(""))
                    TextField("Phone pad (should fall back to system keyboard)", text: .constant(""))
                        .keyboardType(.phonePad)
                }

                Section("Mixed text · نص مختلط") {
                    MultilineTestField()
                }
            }
            .navigationTitle("BKeyboard · TS-01")
        }
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)").font(.headline).monospacedDigit()
            Text(text).font(.subheadline)
        }
    }
}

private struct TestField: View {
    let title: String
    let keyboard: UIKeyboardType
    let returnKey: SubmitLabel
    var capitalization: TextInputAutocapitalization = .sentences
    @State private var text = ""

    init(title: String, keyboard: UIKeyboardType, returnKey: UIReturnKeyType,
         capitalization: TextInputAutocapitalization = .sentences) {
        self.title = title
        self.keyboard = keyboard
        self.capitalization = capitalization
        switch returnKey {
        case .go: self.returnKey = .go
        case .search: self.returnKey = .search
        case .send: self.returnKey = .send
        case .next: self.returnKey = .next
        case .done: self.returnKey = .done
        default: self.returnKey = .return
        }
    }

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboard)
            .submitLabel(returnKey)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
    }
}

private struct MultilineTestField: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("جرّب: أرسل forecast للمبيعات · راجع inventory قبل التحميص · The المحمصة report is ready")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .frame(minHeight: 140)
        }
    }
}
