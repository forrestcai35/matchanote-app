import SwiftUI
import PencilKit
import UniformTypeIdentifiers
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

// Draggable Text Block View - displays content wrapped in """ with drag capability
struct DraggableTextBlockView: View {
    let content: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDragging = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Drag indicator icon
            Image(systemName: "hand.draw")
                .font(.caption)
                .foregroundColor(.blue.opacity(0.7))
                .padding(.top, 4)

            // Content text (plain, no markdown rendering)
            Text(stripMarkdown(content))
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                        )
                        .foregroundColor(.blue.opacity(isDragging ? 0.8 : 0.4))
                )
        )
        .onDrag {
            isDragging = true
            // Return plain text without markdown formatting
            let plainText = stripMarkdown(content)
            return NSItemProvider(object: plainText as NSString)
        }
        .onChange(of: isDragging) { _, newValue in
            if newValue {
                // Reset after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isDragging = false
                }
            }
        }
    }

    // Strip markdown formatting to get plain text
    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // Remove bold (**text**)
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)

        // Remove italic (*text*)
        result = result.replacingOccurrences(of: "(?<!\\*)\\*(?!\\*)(.+?)\\*(?!\\*)", with: "$1", options: .regularExpression)

        // Remove headings (## or ###)
        result = result.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FormattedTextView: View {
    let text: String
    
    var body: some View {
        let blocks = parseTextBlocks(text)
        
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .paragraph(let content):
                    createFormattedText(content, isHeading: false)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .heading(let content):
                    createFormattedText(content, isHeading: true)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, index == 0 ? 0 : 4)

                case .listItem(let content, let isNumbered, let number):
                    HStack(alignment: .top, spacing: 8) {
                        Text(isNumbered ? "\(number)." : "•")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .frame(width: 20, alignment: .leading)

                        createFormattedText(content, isHeading: false)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                case .draggableBlock(let content):
                    DraggableTextBlockView(content: content)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .empty:
                    EmptyView()
                }
            }
        }
    }
    
    // Creates formatted text with inline bold/italic
    private func createFormattedText(_ content: String, isHeading: Bool) -> Text {
        let segments = parseInlineFormatting(content)
        
        var result = Text("")
        for segment in segments {
            var segmentText = Text(segment.text)
            
            if segment.isBold && segment.isItalic {
                segmentText = segmentText.bold().italic()
            } else if segment.isBold {
                segmentText = segmentText.bold()
            } else if segment.isItalic {
                segmentText = segmentText.italic()
            }
            
            result = Text("\(result)\(segmentText)")
        }
        
        if isHeading {
            return result
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
        } else {
            return result
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
    
    // Parse text into blocks (paragraphs, headings, lists)
    private func parseTextBlocks(_ text: String) -> [TextBlock] {
        var blocks: [TextBlock] = []
        let lines = text.components(separatedBy: .newlines)

        var currentListNumber = 1
        var inList = false
        var lastWasEmpty = false
        var inDraggableBlock = false
        var draggableContent: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for draggable block delimiter (""")
            if trimmedLine == "\"\"\"" {
                if inDraggableBlock {
                    // End of draggable block - create the block with collected content
                    let content = draggableContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !content.isEmpty {
                        blocks.append(.draggableBlock(content))
                    }
                    draggableContent = []
                    inDraggableBlock = false
                } else {
                    // Start of draggable block
                    inDraggableBlock = true
                    draggableContent = []
                }
                inList = false
                currentListNumber = 1
                lastWasEmpty = false
                continue
            }

            // If we're inside a draggable block, collect the line
            if inDraggableBlock {
                draggableContent.append(line)
                continue
            }

            // Empty line - only add spacing if previous wasn't empty (avoid multiple blank lines)
            if trimmedLine.isEmpty {
                if !lastWasEmpty && !blocks.isEmpty {
                    blocks.append(.empty)
                }
                lastWasEmpty = true
                inList = false
                currentListNumber = 1
                continue
            }

            lastWasEmpty = false

            // Heading (## or ###)
            if trimmedLine.hasPrefix("##") {
                let content = trimmedLine.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                blocks.append(.heading(content))
                inList = false
                currentListNumber = 1
                continue
            }

            // Numbered list (1., 2., 3., etc.)
            if let match = trimmedLine.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                let content = String(trimmedLine[match.upperBound...])
                blocks.append(.listItem(content, isNumbered: true, number: currentListNumber))
                currentListNumber += 1
                inList = true
                continue
            }

            // Bulleted list (-, •, *)
            if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") {
                let content = String(trimmedLine.dropFirst(2))
                blocks.append(.listItem(content, isNumbered: false, number: 0))
                inList = true
                continue
            }

            // Regular paragraph
            blocks.append(.paragraph(trimmedLine))
            if !inList {
                currentListNumber = 1
            }
        }

        return blocks
    }
    
    // Parse inline formatting (bold, italic) - strips markdown syntax
    private func parseInlineFormatting(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            // Look for **bold** patterns first (longer pattern takes precedence)
            if let boldRange = findPattern(text, from: currentIndex, open: "**", close: "**") {
                // Add text before bold
                if boldRange.contentStart > currentIndex {
                    let beforeText = String(text[currentIndex..<boldRange.openStart])
                    if !beforeText.isEmpty {
                        segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                    }
                }
                
                // Add bold text (without the ** markers)
                let boldText = String(text[boldRange.contentStart..<boldRange.contentEnd])
                segments.append(TextSegment(text: boldText, isBold: true, isItalic: false))
                currentIndex = boldRange.closeEnd
            } else if let italicRange = findPattern(text, from: currentIndex, open: "*", close: "*") {
                // Add text before italic
                if italicRange.contentStart > currentIndex {
                    let beforeText = String(text[currentIndex..<italicRange.openStart])
                    if !beforeText.isEmpty {
                        segments.append(TextSegment(text: beforeText, isBold: false, isItalic: false))
                    }
                }
                
                // Add italic text (without the * markers)
                let italicText = String(text[italicRange.contentStart..<italicRange.contentEnd])
                segments.append(TextSegment(text: italicText, isBold: false, isItalic: true))
                currentIndex = italicRange.closeEnd
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
    
    private struct PatternRange {
        let openStart: String.Index
        let contentStart: String.Index
        let contentEnd: String.Index
        let closeEnd: String.Index
    }
    
    private func findPattern(_ text: String, from startIndex: String.Index, open: String, close: String) -> PatternRange? {
        guard let openRange = text.range(of: open, range: startIndex..<text.endIndex) else { return nil }
        let afterOpen = openRange.upperBound
        
        guard let closeRange = text.range(of: close, range: afterOpen..<text.endIndex) else { return nil }
        
        return PatternRange(
            openStart: openRange.lowerBound,
            contentStart: afterOpen,
            contentEnd: closeRange.lowerBound,
            closeEnd: closeRange.upperBound
        )
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

enum TextBlock {
    case paragraph(String)
    case heading(String)
    case listItem(String, isNumbered: Bool, number: Int)
    case draggableBlock(String)
    case empty
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

