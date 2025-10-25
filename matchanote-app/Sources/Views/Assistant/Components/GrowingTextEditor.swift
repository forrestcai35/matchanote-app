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
  @State private var textEditorHeight: CGFloat = 60
  @State private var heightCalculationTimer: Timer?
  @State private var lastCalculatedText: String = ""
  let maxHeight: CGFloat = 200
  let placeholderText: String
  var submitsOnReturn: Bool = false
  var onSubmit: (() -> Void)? = nil
  
  // Cache screen width to avoid repeated UIScreen calls
  #if canImport(UIKit)
  private static let cachedScreenWidth = UIScreen.main.bounds.width
  #else
  private static let cachedScreenWidth: CGFloat = 800 // Default width for macOS
  #endif
  private let textWidth = Self.cachedScreenWidth - 80

  var body: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $text)
        .frame(height: min(max(textEditorHeight, 80), maxHeight))
        .scrollContentBackground(.hidden)
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
          // Only recalculate if text actually changed and is significantly different
          if newValue != lastCalculatedText && abs(newValue.count - lastCalculatedText.count) > 2 {
            heightCalculationTimer?.invalidate()
            heightCalculationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
              calculateTextHeight(for: newValue)
              lastCalculatedText = newValue
            }
          }
        }
        .background(StaticKeyboardBackgroundFix())


      if text.isEmpty {
        Text(placeholderText)
          .font(.system(size: 15))
          .foregroundColor(.gray.opacity(0.7))
          .padding(.horizontal, 4)
          .padding(.vertical, 8)
          .allowsHitTesting(false)
      }
    }
    .onDisappear {
      heightCalculationTimer?.invalidate()
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
  
  private func calculateTextHeight(for text: String) {
    let lineHeight: CGFloat = 20 
    let lineCount = max(1, text.components(separatedBy: .newlines).count)
    let estimatedHeight = CGFloat(lineCount) * lineHeight + 20 
    
    // Only update if the change is significant to avoid unnecessary redraws
    let newHeight = min(max(estimatedHeight, 60), maxHeight)
    if abs(newHeight - textEditorHeight) > 5 {
      textEditorHeight = newHeight
    }
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
