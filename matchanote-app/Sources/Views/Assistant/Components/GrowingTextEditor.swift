import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

struct GrowingTextEditor: View {
  @Binding var text: String
  @FocusState private var isFocused: Bool
  @Binding var isTextEditorFocused: Bool
  let maxHeight: CGFloat = 200
  let placeholderText: String
  var submitsOnReturn: Bool = false
  var onSubmit: (() -> Void)? = nil

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextField(placeholderText, text: $text, axis: .vertical)
        .lineLimit(1...8)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(minHeight: 40, alignment: .topLeading)
        .focused($isFocused)
        .onChange(of: isFocused) { _, newValue in
          isTextEditorFocused = newValue
        }
        .onChange(of: text) { oldValue, newValue in
          // If configured, treat Return as submit (single trailing newline typed)
          if submitsOnReturn,
             newValue.count == oldValue.count + 1,
             newValue.hasSuffix("\n") {
            // Remove the trailing newline and submit
            text = String(newValue.dropLast())
            onSubmit?()
            dismissKeyboard()
            return
          }
        }
        .background(StaticKeyboardBackgroundFix())
    }
  }
  
  // Dismisses the keyboard on the current platform
  private func dismissKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #elseif canImport(AppKit)
    NSApp.keyWindow?.makeFirstResponder(nil)
    #endif
  }
}

#if canImport(UIKit)
  struct StaticKeyboardBackgroundFix: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.backgroundColor = UIColor.clear
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
      // No-op to prevent unnecessary updates
    }
  }
#else
  struct StaticKeyboardBackgroundFix: View {
    var body: some View {
      EmptyView()
    }
  }
#endif
