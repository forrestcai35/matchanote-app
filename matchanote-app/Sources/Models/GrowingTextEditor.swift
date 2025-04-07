import SwiftUI
import matchanote_app

struct GrowingTextEditor: View {
  @Binding var text: String
  @State private var textEditorHeight: CGFloat = 60
  let maxHeight: CGFloat = 200
  let placeholderText: String

  var body: some View {
    ZStack(alignment: .topLeading) {
      if text.isEmpty {
        Text(placeholderText)
          .foregroundColor(.gray.opacity(0.7))
          .padding(.horizontal, 5)
          .padding(.top, 8)
          .allowsHitTesting(false)
      }

      TextEditor(text: $text)
        .frame(height: min(max(textEditorHeight, 80), maxHeight))
        .onChange(of: text) { newValue in
          let size = CGSize(width: UIScreen.main.bounds.width - 80, height: .infinity)
          let estimatedSize = newValue.boundingRect(
            with: size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16)],
            context: nil
          )

          // Add some padding for better UX
          textEditorHeight = min(estimatedSize.height + 30, maxHeight)
        }
    }
  }
}
