import SwiftUI
import PencilKit
// Message View Components (shared with AIAssistantView)
struct UserMessageView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User Message Text box
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("User")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                if !message.model.isEmpty {
                    HStack {
                        Text(message.model)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark 
                        ? Color.gray.opacity(0.1) 
                        : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                colorScheme == .dark 
                                    ? Color.gray.opacity(0.3) 
                                    : Color.gray.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AssistantMessageView: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCopyConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Plain text response underneath user message with basic formatting support
            FormattedTextView(text: message.content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                if !message.model.isEmpty {
                    Text(message.model)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Copy button
                Button(action: {
                    copyToClipboard(message.content)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showingCopyConfirmation ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                        Text(showingCopyConfirmation ? "Copied!" : "Copy")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showingCopyConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingCopyConfirmation = false
            }
        }
    }
}

struct FormattedTextView: View {
    let text: String
    
    var body: some View {
        let formattedText = parseFormattedText(text)
        
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(formattedText.enumerated()), id: \.offset) { index, segment in
                if segment.isBold && segment.isItalic {
                    Text(segment.text)
                        .font(.system(size: 15))
                        .fontWeight(.bold)
                        .italic()
                } else if segment.isBold {
                    Text(segment.text)
                        .font(.system(size: 15))
                        .fontWeight(.bold)
                } else if segment.isItalic {
                    Text(segment.text)
                        .font(.system(size: 15))
                        .italic()
                } else {
                    Text(segment.text)
                        .font(.system(size: 15))
                }
            }
        }
    }
    
    private func parseFormattedText(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Look for **bold** patterns first (longer pattern takes precedence)
            if let boldRange = findPattern(text, from: currentIndex, open: "**", close: "**") {
                // Add text before bold
                if boldRange.start > currentIndex {
                    let beforeText = String(text[currentIndex..<boldRange.start])
                    if !beforeText.isEmpty {
                        segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                    }
                }
                
                // Add bold text
                let boldText = String(text[boldRange.start..<boldRange.end])
                segments.append(TextSegment(text: boldText, isBold: true, isItalic: false))
                currentIndex = boldRange.end
            } else if let italicRange = findPattern(text, from: currentIndex, open: "*", close: "*") {
                // Add text before italic
                if italicRange.start > currentIndex {
                    let beforeText = String(text[currentIndex..<italicRange.start])
                    if !beforeText.isEmpty {
                        segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                    }
                }
                
                // Add italic text
                let italicText = String(text[italicRange.start..<italicRange.end])
                segments.append(TextSegment(text: italicText, isBold: false, isItalic: true))
                currentIndex = italicRange.end
            } else {
                // Check for malformed patterns and clean them up
                if let malformedRange = findMalformedPattern(text, from: currentIndex) {
                    // Add text before malformed pattern
                    if malformedRange.start > currentIndex {
                        let beforeText = String(text[currentIndex..<malformedRange.start])
                        if !beforeText.isEmpty {
                            segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                        }
                    }
                    
                    // Add cleaned text (remove malformed markdown)
                    let malformedText = String(text[malformedRange.start..<malformedRange.end])
                    let cleanedText = cleanMalformedMarkdown(malformedText)
                    segments.append(TextSegment(text: cleanedText, isBold: false, isItalic: false))
                    currentIndex = malformedRange.end
                } else {
                    // No more formatting, add remaining text
                    let remainingText = String(text[currentIndex...])
                    if !remainingText.isEmpty {
                        segments.append(TextSegment(text: remainingText, isBold: false, isItalic: false))
                    }
                    break
                }
            }
        }
        
        return segments.isEmpty ? [TextSegment(text: text, isBold: false, isItalic: false)] : segments
    }
    
    private func findPattern(_ text: String, from startIndex: String.Index, open: String, close: String) -> (start: String.Index, end: String.Index)? {
        guard let openRange = text.range(of: open, range: startIndex..<text.endIndex) else { return nil }
        let afterOpen = openRange.upperBound
        
        guard let closeRange = text.range(of: close, range: afterOpen..<text.endIndex) else { return nil }
        
        return (start: afterOpen, end: closeRange.lowerBound)
    }
    
    private func findMalformedPattern(_ text: String, from startIndex: String.Index) -> (start: String.Index, end: String.Index)? {
        // Look for patterns like "** text * *" or similar malformed markdown
        let patterns = [
            "** ",  // ** followed by space
            " * *", // space * space *
            "** *", // ** followed by *
            "* *",  // * space *
            "**\"", // ** followed by quote
            "\"**", // quote followed by **
        ]
        
        for pattern in patterns {
            if let range = text.range(of: pattern, range: startIndex..<text.endIndex) {
                // Find the end of this malformed section (until we hit a word boundary or end)
                var endIndex = range.upperBound
                while endIndex < text.endIndex {
                    let char = text[endIndex]
                    if char.isWhitespace || char == "*" || char == "\"" {
                        endIndex = text.index(after: endIndex)
                    } else {
                        break
                    }
                }
                return (start: range.lowerBound, end: endIndex)
            }
        }
        
        return nil
    }
    
    private func cleanMalformedMarkdown(_ text: String) -> String {
        var cleaned = text
        
        // Remove malformed patterns like "** text * *" -> "text"
        cleaned = cleaned.replacingOccurrences(of: "** ", with: "")
        cleaned = cleaned.replacingOccurrences(of: " * *", with: "")
        cleaned = cleaned.replacingOccurrences(of: "** *", with: "")
        cleaned = cleaned.replacingOccurrences(of: "* *", with: "")
        
        // Handle quotes inside bold formatting: **"text"** -> text
        cleaned = cleaned.replacingOccurrences(of: "**\"", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\"**", with: "")
        
        // Clean up any remaining asterisks that are not part of proper markdown
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

struct TextSegment {
    let text: String
    let isBold: Bool
    let isItalic: Bool
}

// Enhanced AI Assistant State that includes our new capabilities
class EnhancedAIAssistantState: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var userInput = "" {
        didSet {
            // Debounce user input changes to reduce UI updates
            if userInput != oldValue {
                userInputDebounceTimer?.invalidate()
                userInputDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    // Optional: Add any debounced logic here if needed
                }
            }
        }
    }
    
    // Callback to save current canvas data before analysis
    var saveCanvasDataCallback: (() -> Void)?
    @Published var selectedModel = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var tempMediaItems: [MediaItem] = []
    @Published var availableModels: [String] = []
    @Published var subscriptionManager = SubscriptionManager()

    // Enhanced AI capabilities
    @Published var currentMode: AIMode = .chat

    @Published var showingAnalysisResults = false
    @Published var currentNote: Note?
    
    // Performance optimization
    private var userInputDebounceTimer: Timer?

    enum AIMode {
        case chat
        case analysis
        case suggestions
    }
    
    deinit {
        userInputDebounceTimer?.invalidate()
    }
}
