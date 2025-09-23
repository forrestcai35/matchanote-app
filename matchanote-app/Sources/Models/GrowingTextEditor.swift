import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

struct GrowingTextEditor: View {
  @Binding var text: String
  @State private var textEditorHeight: CGFloat = 60
  @State private var heightCalculationTimer: Timer?
  let maxHeight: CGFloat = 200
  let placeholderText: String
  
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
        .onChange(of: text) { oldValue, newValue in
          // Debounce height calculation to improve performance
          heightCalculationTimer?.invalidate()
          heightCalculationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            calculateTextHeight(for: newValue)
          }
        }
        .background(OptimizedKeyboardBackgroundFix())

      if text.isEmpty {
        Text(placeholderText)
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
  
  private func calculateTextHeight(for text: String) {
    let size = CGSize(width: textWidth, height: .infinity)
    #if canImport(UIKit)
    let font = UIFont.systemFont(ofSize: 16)
    #else
    let font = NSFont.systemFont(ofSize: 16)
    #endif
    let estimatedSize = text.boundingRect(
      with: size,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: [.font: font],
      context: nil
    )
    textEditorHeight = min(estimatedSize.height + 30, maxHeight)
  }
}

#if canImport(UIKit)
  struct OptimizedKeyboardBackgroundFix: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      view.backgroundColor = UIColor.clear
      
      // More efficient approach - use a single async call with better error handling
      DispatchQueue.main.async {
        self.configureTextView(in: view)
      }
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
    
    private func configureTextView(in view: UIView) {
      // More efficient text view finding
      var currentView: UIView? = view
      var textView: UITextView?
      
      // Walk up the view hierarchy more efficiently
      while currentView != nil && textView == nil {
        if let foundTextView = currentView as? UITextView {
          textView = foundTextView
          break
        }
        currentView = currentView?.superview
      }
      
      textView?.inputAccessoryView = nil
    }
  }
#else
  struct OptimizedKeyboardBackgroundFix: View {
    var body: some View {
      EmptyView()
    }
  }
#endif
