import SwiftUI
import UIKit

// Utility struct for textbox calculations
struct TextBoxUtilities {
    // Calculate the size needed for a textbox to fit the given text
    static func calculateTextBoxSize(for text: String, fontSize: CGFloat, fontFamily: String, maxWidth: CGFloat) -> CGSize {
        guard !text.isEmpty else {
            // Return minimum size for empty text
            return CGSize(width: 200, height: 60)
        }

        let padding: CGFloat = 16 // 8pt padding on each side
        let maxTextWidth = maxWidth - padding

        // Create attributed string with the font to measure
        let font: UIFont
        if fontFamily == "System" {
            font = UIFont.systemFont(ofSize: fontSize)
        } else if let customFont = UIFont(name: fontFamily, size: fontSize) {
            font = customFont
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        // Calculate bounding rect with maximum width constraint
        let constraintSize = CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        // Add padding and ensure minimum dimensions
        let width = min(max(boundingRect.width + padding, 120), maxWidth)
        let height = max(boundingRect.height + padding, 40)

        return CGSize(width: ceil(width), height: ceil(height))
    }
}

struct TextBoxOverlay: View {
    @ObservedObject var textBoxManager: TextBoxManager
    let pageIndex: Int
    let canvasSize: CGSize
    var isTextBoxToolActive: Bool = false

    var body: some View {
        let hasTextBoxes = !textBoxManager.textBoxes(for: pageIndex).isEmpty
        let shouldInterceptBackground = textBoxManager.hasSelectedTextBox || textBoxManager.isEditingText || isTextBoxToolActive
        let _ = print("🟦 TextBoxOverlay render: page=\(pageIndex), hasTextBoxes=\(hasTextBoxes), shouldInterceptBg=\(shouldInterceptBackground), isTextBoxToolActive=\(isTextBoxToolActive)")
        
        ZStack {
            // Background tap layer - intercepts when something is selected OR textbox tool is active
            if shouldInterceptBackground {
                Color.clear
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        print("🟢 BACKGROUND TAP - location: \(location)")
                        if isTextBoxToolActive && !textBoxManager.hasSelectedTextBox {
                            // Create new textbox at tap location
                            print("🟢 Creating textbox at \(location)")
                            textBoxManager.addTextBox(to: pageIndex, at: location)
                        } else {
                            // Deselect existing selection
                            print("🟢 Deselecting")
                            textBoxManager.deselectAllTextBoxes()
                        }
                    }
            }
            
            // Textboxes for this page (rendered on top, will intercept their own taps)
            ForEach(textBoxManager.textBoxes(for: pageIndex)) { textBox in
                TextBoxView(
                    textBox: textBox,
                    textBoxManager: textBoxManager,
                    pageIndex: pageIndex,
                    canvasSize: canvasSize
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }
}

struct TextBoxView: View {
    let textBox: TextBox
    @ObservedObject var textBoxManager: TextBoxManager
    let pageIndex: Int
    let canvasSize: CGSize

    @State private var dragOffset: CGSize = .zero
    @State private var editingText: String = ""
    @State private var currentSize: CGSize = .zero

    var isSelected: Bool {
        textBoxManager.selectedTextBoxId == textBox.id
    }
    
    var isEditing: Bool {
        textBoxManager.editingTextBoxId == textBox.id && textBoxManager.isEditingText
    }

    var body: some View {
        let _ = print("📦 TextBoxView render: id=\(textBox.id), pos=\(textBox.position), size=\(textBox.size), isSelected=\(isSelected), isEditing=\(isEditing)")
        
        ZStack {
            // Content area (text + background) - this defines the main hit area
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: textBox.cornerRadius)
                    .fill(textBox.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: textBox.cornerRadius)
                            .stroke(textBox.borderColor, lineWidth: textBox.borderWidth)
                    )

                // Text content
                if isEditing {
                TextField("Type here...", text: $editingText, axis: .vertical)
                    .font(fontForTextBox(textBox))
                    .foregroundColor(textBox.textColor)
                    .multilineTextAlignment(textBox.textAlignment.textAlignment)
                    .padding(8)
                    .onSubmit {
                        finishEditing()
                    }
                    .onAppear {
                        editingText = textBox.text
                    }
                    .onChange(of: editingText) { _, newValue in
                        // Sync with manager so deletion check works
                        textBoxManager.currentEditingText = newValue

                        // Auto-resize textbox based on content
                        let newSize = TextBoxUtilities.calculateTextBoxSize(for: newValue, fontSize: textBox.fontSize, fontFamily: textBox.fontFamily, maxWidth: 600)
                        if newSize != textBox.size {
                            var updatedTextBox = textBox
                            updatedTextBox.size = newSize
                            updatedTextBox.text = newValue
                            textBoxManager.updateTextBox(updatedTextBox)
                        }
                    }
            } else {
                // Non-interactive text display
                Text(textBox.text.isEmpty ? "Type here..." : textBox.text)
                    .font(fontForTextBox(textBox))
                    .foregroundColor(textBox.text.isEmpty ? .gray.opacity(0.5) : textBox.textColor)
                    .multilineTextAlignment(textBox.textAlignment.textAlignment)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: textBox.textAlignment.alignment)
            }
            }
            .contentShape(Rectangle()) // Limit hit area to content frame only
            
            // Selection controls - show whenever selected (even during editing)
            // These are outside the contentShape so they can be hit outside the frame
            if isSelected {
                selectionControls()
            }
        }
        .frame(
            width: currentSize.width > 0 ? currentSize.width : textBox.size.width,
            height: currentSize.height > 0 ? currentSize.height : textBox.size.height
        )
        .opacity(textBox.opacity)
        .rotationEffect(.degrees(textBox.rotation))
        .offset(dragOffset)
        .position(
            x: textBox.position.x + (currentSize.width > 0 ? currentSize.width : textBox.size.width) / 2,
            y: textBox.position.y + (currentSize.height > 0 ? currentSize.height : textBox.size.height) / 2
        )
        .zIndex(Double(textBox.zIndex + (isSelected ? 1000 : 0)))
        .gesture(
            DragGesture(minimumDistance: 5) // Small distance to avoid conflicting with text selection
                .onChanged { value in
                    if isSelected {
                        print("🔵 DRAG DETECTED on textbox \(textBox.id), translation: \(value.translation)")
                        dragOffset = value.translation
                    } else {
                        print("🔵 DRAG IGNORED - textbox not selected")
                    }
                }
                .onEnded { value in
                    print("🔵 DRAG ENDED on textbox \(textBox.id), isSelected: \(isSelected)")
                    if isSelected {
                        // No clamping - allow free positioning like CanvasImageView
                        let newPosition = CGPoint(
                            x: textBox.position.x + value.translation.width,
                            y: textBox.position.y + value.translation.height
                        )

                        var updatedTextBox = textBox
                        updatedTextBox.position = newPosition
                        textBoxManager.updateTextBox(updatedTextBox)
                    }
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            print("👆 TAP on textbox \(textBox.id), isSelected: \(isSelected), isEditing: \(isEditing)")
            if !isSelected {
                print("  → Selecting textbox")
                textBoxManager.selectTextBox(withId: textBox.id)
            } else if !isEditing {
                print("  → Starting edit mode")
                startEditing()
            } else {
                print("  → Already editing, ignoring")
            }
        }
        .onChange(of: isEditing) { wasEditing, nowEditing in
            if nowEditing && !wasEditing {
                // Started editing - initialize text
                editingText = textBox.text
            } else if !nowEditing && wasEditing {
                // Stopped editing - save text
                var updatedTextBox = textBox
                updatedTextBox.text = editingText
                textBoxManager.updateTextBox(updatedTextBox)
            }
        }
        .contextMenu {
            Button("Edit Text") {
                startEditing()
            }
            Divider()
            Button("Cut") {
                copyTextBox()
                textBoxManager.deleteTextBox(withId: textBox.id, fromPage: pageIndex)
            }
            Button("Copy") {
                copyTextBox()
            }
            Button("Paste") {
                pasteTextBox()
            }
            .disabled(!canPaste())
            Divider()
            Button("Duplicate") {
                duplicateTextBox()
            }
            Button("Delete", role: .destructive) {
                textBoxManager.deleteTextBox(withId: textBox.id, fromPage: pageIndex)
            }
        }
    }

    @ViewBuilder
    private func selectionControls() -> some View {
        let boxWidth = currentSize.width > 0 ? currentSize.width : textBox.size.width
        let boxHeight = currentSize.height > 0 ? currentSize.height : textBox.size.height

        ZStack {
            // Selection border
            RoundedRectangle(cornerRadius: textBox.cornerRadius)
                .stroke(Color.blue, lineWidth: 2)
                .background(Color.clear)

            // Delete button (top-right corner)
            Button(action: {
                textBoxManager.deleteTextBox(withId: textBox.id, fromPage: pageIndex)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 28, height: 28)

                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 64, height: 64)
            .contentShape(Rectangle())
            .offset(x: boxWidth/2 + 14, y: -boxHeight/2 - 14)
            .allowsHitTesting(true)

            // Corner handle - free horizontal and vertical resizing (bottom-right)
            FreeResizeHandle(
                startSize: currentSize.width > 0 ? currentSize : textBox.size,
                onChanged: { newSize in
                    currentSize = newSize
                },
                onEnd: {
                    if currentSize.width > 0 && currentSize.height > 0 {
                        var updatedTextBox = textBox
                        updatedTextBox.size = currentSize
                        textBoxManager.updateTextBox(updatedTextBox)
                    }
                    currentSize = .zero
                }
            )
            .offset(x: boxWidth/2 + 14, y: boxHeight/2 + 14)
            .allowsHitTesting(true)
        }
    }

    private func fontForTextBox(_ textBox: TextBox) -> Font {
        let fontName = textBox.fontFamily == "System" ? ".SFUI-Regular" : textBox.fontFamily

        if let uiFont = UIFont(name: fontName, size: textBox.fontSize) {
            return Font(uiFont)
        } else {
            return .system(size: textBox.fontSize)
        }
    }

    private func startEditing() {
        editingText = textBox.text
        textBoxManager.currentEditingText = textBox.text
        textBoxManager.isEditingText = true
        textBoxManager.editingTextBoxId = textBox.id
    }

    private func finishEditing() {
        // Save the text and updated size before clearing editing state
        var updatedTextBox = textBox
        updatedTextBox.text = editingText

        // Update size to fit final text content
        let newSize = TextBoxUtilities.calculateTextBoxSize(for: editingText, fontSize: textBox.fontSize, fontFamily: textBox.fontFamily, maxWidth: 600)
        updatedTextBox.size = newSize

        textBoxManager.updateTextBox(updatedTextBox)

        textBoxManager.isEditingText = false
        textBoxManager.editingTextBoxId = nil
    }

    private func duplicateTextBox() {
        let duplicate = TextBox(
            text: textBox.text,
            position: CGPoint(x: textBox.position.x + 20, y: textBox.position.y + 20),
            size: textBox.size,
            fontSize: textBox.fontSize,
            fontFamily: textBox.fontFamily,
            textColor: textBox.textColor,
            backgroundColor: textBox.backgroundColor,
            textAlignment: textBox.textAlignment,
            rotation: textBox.rotation,
            opacity: textBox.opacity,
            cornerRadius: textBox.cornerRadius,
            borderWidth: textBox.borderWidth,
            borderColor: textBox.borderColor,
            zIndex: textBox.zIndex,
            pageIndex: textBox.pageIndex
        )

        if textBoxManager.textBoxesByPage[textBox.pageIndex] == nil {
            textBoxManager.textBoxesByPage[textBox.pageIndex] = []
        }
        textBoxManager.textBoxesByPage[textBox.pageIndex]?.append(duplicate)
    }

    private func copyTextBox() {
        textBoxManager.copiedTextBox = textBox
    }

    private func pasteTextBox() {
        guard let copiedTextBox = textBoxManager.copiedTextBox else { return }

        let pastedTextBox = TextBox(
            text: copiedTextBox.text,
            position: CGPoint(x: textBox.position.x + 30, y: textBox.position.y + 30),
            size: copiedTextBox.size,
            fontSize: copiedTextBox.fontSize,
            fontFamily: copiedTextBox.fontFamily,
            textColor: copiedTextBox.textColor,
            backgroundColor: copiedTextBox.backgroundColor,
            textAlignment: copiedTextBox.textAlignment,
            rotation: copiedTextBox.rotation,
            opacity: copiedTextBox.opacity,
            cornerRadius: copiedTextBox.cornerRadius,
            borderWidth: copiedTextBox.borderWidth,
            borderColor: copiedTextBox.borderColor,
            zIndex: copiedTextBox.zIndex,
            pageIndex: textBox.pageIndex
        )

        if textBoxManager.textBoxesByPage[textBox.pageIndex] == nil {
            textBoxManager.textBoxesByPage[textBox.pageIndex] = []
        }
        textBoxManager.textBoxesByPage[textBox.pageIndex]?.append(pastedTextBox)
    }

    private func canPaste() -> Bool {
        return textBoxManager.copiedTextBox != nil
    }

    // Calculate the size needed for a textbox to fit the given text
    private func calculateTextBoxSize(for text: String, fontSize: CGFloat, fontFamily: String, maxWidth: CGFloat) -> CGSize {
        guard !text.isEmpty else {
            // Return minimum size for empty text
            return CGSize(width: 200, height: 60)
        }

        let padding: CGFloat = 16 // 8pt padding on each side
        let maxTextWidth = maxWidth - padding

        // Create attributed string with the font to measure
        let font: UIFont
        if fontFamily == "System" {
            font = UIFont.systemFont(ofSize: fontSize)
        } else if let customFont = UIFont(name: fontFamily, size: fontSize) {
            font = customFont
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        // Calculate bounding rect with maximum width constraint
        let constraintSize = CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        // Add padding and ensure minimum dimensions
        let width = min(max(boundingRect.width + padding, 120), maxWidth)
        let height = max(boundingRect.height + padding, 40)

        return CGSize(width: ceil(width), height: ceil(height))
    }
}

// Text formatting controls view
struct TextBoxFormattingControls: View {
    @ObservedObject var textBoxManager: TextBoxManager
    @Environment(\.colorScheme) private var colorScheme

    // State for color picker
    @State private var showColorPicker = false
    @State private var newTextColor: Color = .black

    var body: some View {
        let selectedTextBox = textBoxManager.selectedTextBox
        let hasSelection = selectedTextBox != nil
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Font family dropdown
                Menu {
                    ForEach(textBoxManager.availableFonts, id: \.self) { font in
                        Button(font) {
                            updateTextBoxFont(font)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedTextBox?.fontFamily ?? "System")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                }
                .disabled(!hasSelection)
                .opacity(hasSelection ? 1.0 : 0.5)

                // Font size controls
                HStack(spacing: 4) {
                    Button(action: { adjustFontSize(-2) }) {
                        Image(systemName: "minus")
                            .font(.caption)
                    }
                    .disabled(!hasSelection || (selectedTextBox?.fontSize ?? 8) <= 8)

                    Text("\(Int(selectedTextBox?.fontSize ?? 16))")
                        .font(.caption)
                        .frame(width: 24)

                    Button(action: { adjustFontSize(2) }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .disabled(!hasSelection || (selectedTextBox?.fontSize ?? 16) >= 72)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
                .opacity(hasSelection ? 1.0 : 0.5)

                // Text alignment buttons
                HStack(spacing: 2) {
                    ForEach(TextAlignment.allCases, id: \.self) { alignment in
                        Button(action: { updateTextAlignment(alignment) }) {
                            Image(systemName: alignmentIcon(for: alignment))
                                .font(.caption)
                                .foregroundColor((selectedTextBox?.textAlignment == alignment && hasSelection) ? .blue : .primary)
                        }
                        .frame(width: 24, height: 20)
                        .disabled(!hasSelection)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
                .opacity(hasSelection ? 1.0 : 0.5)

                // Text color
                Button(action: { showColorPicker = true }) {
                    Circle()
                        .fill(selectedTextBox?.textColor ?? .black)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Color.gray, lineWidth: 1)
                        )
                }
                .disabled(!hasSelection)
                .opacity(hasSelection ? 1.0 : 0.5)
                .popover(isPresented: $showColorPicker) {
                    VStack(spacing: 12) {
                        ColorPicker("Text Color", selection: $newTextColor)
                            .padding(.horizontal)
                        Divider()
                        HStack {
                            Button("Cancel") {
                                showColorPicker = false
                            }
                            .foregroundColor(.red)
                            Spacer()
                            Button("Apply") {
                                updateTextColor(newTextColor)
                                showColorPicker = false
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    .frame(minWidth: 200)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.matchalight_dark.opacity(0.1))
        .cornerRadius(8)
    }

    private func updateTextBoxFont(_ fontFamily: String) {
        guard var selectedTextBox = textBoxManager.selectedTextBox else { return }
        selectedTextBox.fontFamily = fontFamily

        // Recalculate size to fit text with new font
        let newSize = TextBoxUtilities.calculateTextBoxSize(for: selectedTextBox.text, fontSize: selectedTextBox.fontSize, fontFamily: fontFamily, maxWidth: 600)
        selectedTextBox.size = newSize

        textBoxManager.updateTextBox(selectedTextBox)
    }

    private func adjustFontSize(_ delta: CGFloat) {
        guard var selectedTextBox = textBoxManager.selectedTextBox else { return }
        selectedTextBox.fontSize = max(8, min(72, selectedTextBox.fontSize + delta))

        // Recalculate size to fit text with new font size
        let newSize = TextBoxUtilities.calculateTextBoxSize(for: selectedTextBox.text, fontSize: selectedTextBox.fontSize, fontFamily: selectedTextBox.fontFamily, maxWidth: 600)
        selectedTextBox.size = newSize

        textBoxManager.updateTextBox(selectedTextBox)
    }

    private func updateTextAlignment(_ alignment: TextAlignment) {
        guard var selectedTextBox = textBoxManager.selectedTextBox else { return }
        selectedTextBox.textAlignment = alignment
        textBoxManager.updateTextBox(selectedTextBox)
    }

    private func updateTextColor(_ color: Color) {
        guard var selectedTextBox = textBoxManager.selectedTextBox else { return }
        selectedTextBox.textColor = color
        textBoxManager.updateTextBox(selectedTextBox)
    }

    private func alignmentIcon(for alignment: TextAlignment) -> String {
        switch alignment {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }
}

// MARK: - Free Resize Handle
struct FreeResizeHandle: View {
    let startSize: CGSize
    let onChanged: (CGSize) -> Void
    let onEnd: () -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: 24, height: 24)
            
            Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .frame(width: 64, height: 64) // Large hit area for easier interaction
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Allow independent horizontal and vertical resizing
                    let newWidth = max(50, startSize.width + value.translation.width)
                    let newHeight = max(50, startSize.height + value.translation.height)
                    
                    let newSize = CGSize(width: newWidth, height: newHeight)
                    onChanged(newSize)
                }
                .onEnded { _ in
                    onEnd()
                }
        )
    }
}