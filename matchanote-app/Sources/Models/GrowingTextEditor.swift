import SwiftUI
import matchanote_app

#if canImport(UIKit)
  import UIKit
#endif

struct GrowingTextEditor: View {
  @Binding var text: String
  @State private var textEditorHeight: CGFloat = 60
  let maxHeight: CGFloat = 200
  let placeholderText: String

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .frame(height: min(max(textEditorHeight, 80), maxHeight))
        .scrollContentBackground(.hidden)  // Make background transparent
        .onChange(of: text) { newValue in
          let size = CGSize(width: UIScreen.main.bounds.width - 80, height: .infinity)
          let estimatedSize = newValue.boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
          )
          textEditorHeight = min(estimatedSize.height + 30, maxHeight)
        }
        // Add UIKit keyboard fix
        .background(KeyboardBackgroundFix())

      if text.isEmpty {
        Text(placeholderText)
          .foregroundColor(.gray.opacity(0.7))
          .padding(.horizontal, 8)
          .padding(.vertical, 8)
          .allowsHitTesting(false)
      }
    }
  }
}

#if canImport(UIKit)
  // Helper to fix keyboard layout constraint conflicts
  struct KeyboardBackgroundFix: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      // Add a method to remove any input accessory view for the text view
      DispatchQueue.main.async {
        // Find the text view in hierarchy
        if let textView = view.superview?.superview?.subviews.first(where: { $0 is UITextView })
          as? UITextView
        {
          // Clear input accessory view to avoid constraint conflicts
          textView.inputAccessoryView = nil
        }
      }
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
  }
#else
  // Fallback for non-UIKit platforms
  struct KeyboardBackgroundFix: View {
    var body: some View {
      EmptyView()
    }
  }
#endif
