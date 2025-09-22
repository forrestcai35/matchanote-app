import SwiftUI


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
        .scrollContentBackground(.hidden)
        .onChange(of: text) { oldValue, newValue in
          let size = CGSize(width: UIScreen.main.bounds.width - 80, height: .infinity)
          let estimatedSize = newValue.boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
          )
          textEditorHeight = min(estimatedSize.height + 30, maxHeight)
        }
        .background(KeyboardBackgroundFix())

      if text.isEmpty {
        Text(placeholderText)
          .foregroundColor(.gray.opacity(0.7))
          .padding(.horizontal, 4)
          .padding(.vertical, 8)
          .allowsHitTesting(false)
      }
    }
  }
}

#if canImport(UIKit)
  struct KeyboardBackgroundFix: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
      let view = UIView()

      DispatchQueue.main.async {
        if let textView = view.superview?.superview?.subviews.first(where: { $0 is UITextView })
          as? UITextView
        {
          textView.inputAccessoryView = nil
        }
      }
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
  }
#else
  struct KeyboardBackgroundFix: View {
    var body: some View {
      EmptyView()
    }
  }
#endif
