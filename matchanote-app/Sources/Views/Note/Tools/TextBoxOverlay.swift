import SwiftUI
import UIKit

// Utility struct for textbox calculations
struct TextBoxUtilities {
    // Calculate the size needed for a textbox to fit the given text
    // Used during editing/resizing - maintains fixed width, adjusts height to fit wrapped text
    static func calculateTextBoxSize(for text: String, fontSize: CGFloat, fontFamily: String, maxWidth: CGFloat) -> CGSize {
        guard !text.isEmpty else {
            // Return minimum size for empty text
            return CGSize(width: 200, height: 30)
        }

        let padding: CGFloat = 8 // 4pt padding on each side (matches UI padding)

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

        // Calculate bounding rect with maximum width constraint (accounting for padding)
        let constraintSize = CGSize(width: maxWidth - padding, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        // Keep width fixed at maxWidth for text wrapping during editing
        // Add padding to height to match UI
        let width = maxWidth
        let height = boundingRect.height + padding // Just use actual height + padding, no minimum

        return CGSize(width: ceil(width), height: ceil(height))
    }
}

struct TextBoxOverlay: View {
    @ObservedObject var textBoxManager: TextBoxManager
    @ObservedObject var imageManager: CanvasImageManager
    @ObservedObject var toolState: ToolState
    let pageIndex: Int
    let canvasSize: CGSize
    var isTextBoxToolActive: Bool = false
    var zoomScale: CGFloat = 1.0

    var body: some View {
          let hasTextBoxes = !textBoxManager.textBoxes(for: pageIndex).isEmpty
        // Only show background tap layer when a textbox is selected/editing (for deselection)
        let shouldInterceptBackground = textBoxManager.hasSelectedTextBox || textBoxManager.isEditingText
        let allowHitTesting = hasTextBoxes || textBoxManager.hasSelectedTextBox || textBoxManager.isEditingText

        ZStack {
            // Background tap layer - intercepts when something is selected for deselection
            if shouldInterceptBackground {
                Color.clear
                    .frame(width: canvasSize.width * zoomScale, height: canvasSize.height * zoomScale)
                    .contentShape(Rectangle())
                    .onTapGesture { _ in
                        // This layer only shows when a textbox is selected
                        // Tapping background deselects and auto-deletes empty textboxes
                        textBoxManager.deselectAllTextBoxes()
                    }
            }
            
            // Textboxes for this page (rendered on top, will intercept their own taps)
            ForEach(textBoxManager.textBoxes(for: pageIndex)) { textBox in
                TextBoxView(
                    textBox: textBox,
                    textBoxManager: textBoxManager,
                    imageManager: imageManager,
                    pageIndex: pageIndex,
                    canvasSize: canvasSize,
                    zoomScale: zoomScale
                )
            }
        }
        .allowsHitTesting(allowHitTesting)
        .frame(width: canvasSize.width * zoomScale, height: canvasSize.height * zoomScale)
        .clipped()
        .coordinateSpace(name: CanvasCoordinateSpace.canvas)
    }
}

struct TextBoxView: View {
    let textBox: TextBox
    @ObservedObject var textBoxManager: TextBoxManager
    @ObservedObject var imageManager: CanvasImageManager
    let pageIndex: Int
    let canvasSize: CGSize
    var zoomScale: CGFloat = 1.0

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: textBox.textAlignment.alignment)
                    .padding(4)
                    .onSubmit {
                        finishEditing()
                    }
                    .onAppear {
                        editingText = textBox.text
                    }
                    .onChange(of: editingText) { _, newValue in
                        // Sync with manager so deletion check works
                        textBoxManager.currentEditingText = newValue

                        // Auto-resize textbox height while maintaining fixed width (text wraps)
                        let newSize = TextBoxUtilities.calculateTextBoxSize(for: newValue, fontSize: textBox.fontSize, fontFamily: textBox.fontFamily, maxWidth: textBox.size.width)
                        if newSize != textBox.size {
                            var updatedTextBox = textBox
                            updatedTextBox.size = newSize
                            updatedTextBox.text = newValue
                            textBoxManager.updateTextBox(updatedTextBox)
                        }
                    }
            } else {
                // Non-interactive text display
                Text(textBox.text)
                    .font(fontForTextBox(textBox))
                    .foregroundColor(textBox.textColor)
                    .multilineTextAlignment(textBox.textAlignment.textAlignment)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: textBox.textAlignment.alignment)
                    .padding(4)
            }
            }
            // Expand hit area with padding for easier tapping
            // Use .interaction contentShape to make the entire padded area tappable
            .contentShape(.interaction, Rectangle().inset(by: -8))
        }
        .frame(
            width: (currentSize.width > 0 ? currentSize.width : textBox.size.width) * zoomScale,
            height: (currentSize.height > 0 ? currentSize.height : textBox.size.height) * zoomScale
        )
        .overlay(
            // Selection controls - overlaid so they can extend outside the frame
            Group {
                if isSelected {
                    selectionControls()
                }
            }
        )
        .opacity(textBox.opacity)
        .rotationEffect(.degrees(textBox.rotation))
        .offset(dragOffset)
        .position(
            x: (textBox.position.x + (currentSize.width > 0 ? currentSize.width : textBox.size.width) / 2) * zoomScale,
            y: (textBox.position.y + (currentSize.height > 0 ? currentSize.height : textBox.size.height) / 2) * zoomScale
        )
        .zIndex(Double(textBox.zIndex + (isSelected ? 1000 : 0)))
        .gesture(
            DragGesture(minimumDistance: 5) // Small distance to avoid conflicting with text selection
                .onChanged { value in
                    if isSelected {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if isSelected {
                        // Convert drag translation from zoomed coordinates to logical coordinates
                        let newPosition = CGPoint(
                            x: textBox.position.x + value.translation.width / zoomScale,
                            y: textBox.position.y + value.translation.height / zoomScale
                        )

                        var updatedTextBox = textBox
                        updatedTextBox.position = newPosition
                        textBoxManager.updateTextBox(updatedTextBox)
                    }
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            if !isSelected {
                imageManager.deselectImage()
                textBoxManager.selectTextBox(withId: textBox.id)
            } else if !isEditing {
                startEditing()
            }
        }
        .onChange(of: isSelected) { _, nowSelected in
            if !nowSelected {
                // Reset currentSize when deselected to ensure clean state on next selection
                currentSize = .zero
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
        let boxWidth = (currentSize.width > 0 ? currentSize.width : textBox.size.width) * zoomScale
        let boxHeight = (currentSize.height > 0 ? currentSize.height : textBox.size.height) * zoomScale
        let handleOffset: CGFloat = 8 // Distance from corner to handle center
        let rotationHandleOffset = CGVector(
            dx: -boxWidth / 2 - handleOffset,
            dy: -boxHeight / 2 - handleOffset
        )
        let centerPoint = CGPoint(
            x: (textBox.position.x + (currentSize.width > 0 ? currentSize.width : textBox.size.width) / 2) * zoomScale,
            y: (textBox.position.y + (currentSize.height > 0 ? currentSize.height : textBox.size.height) / 2) * zoomScale
        )

        ZStack {
            // Selection border
            RoundedRectangle(cornerRadius: textBox.cornerRadius * zoomScale)
                .stroke(Color.blue, lineWidth: 2)
                .background(Color.clear)
                .frame(width: boxWidth, height: boxHeight)

            // Delete button (top-right corner)
            Button(action: {
                textBoxManager.deleteTextBox(withId: textBox.id, fromPage: pageIndex)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 20, height: 20)

                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 64, height: 64)
            .contentShape(Rectangle())
            .offset(x: boxWidth/2 + handleOffset, y: -boxHeight/2 - handleOffset)
            .allowsHitTesting(true)

            // Corner handle - free horizontal and vertical resizing (bottom-right)
            FreeResizeHandle(
                startSize: currentSize.width > 0 ? CGSize(width: currentSize.width * zoomScale, height: currentSize.height * zoomScale) : CGSize(width: textBox.size.width * zoomScale, height: textBox.size.height * zoomScale),
                zoomScale: zoomScale,
                onChanged: { newSize in
                    // Convert back from zoomed size to logical size
                    currentSize = CGSize(width: newSize.width / zoomScale, height: newSize.height / zoomScale)
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
            .offset(x: boxWidth/2 + handleOffset, y: boxHeight/2 + handleOffset)
            .allowsHitTesting(true)

            RotationHandle(
                center: centerPoint,
                initialVector: rotationHandleOffset,
                coordinateSpaceName: CanvasCoordinateSpace.canvas,
                onBegan: {},
                onChanged: { newRotation in
                    var updatedTextBox = textBox
                    updatedTextBox.rotation = TextBox.snapRotation(newRotation)
                    textBoxManager.updateTextBox(updatedTextBox)
                },
                onEnded: { finalRotation in
                    var updatedTextBox = textBox
                    updatedTextBox.rotation = TextBox.snapRotation(finalRotation)
                    textBoxManager.updateTextBox(updatedTextBox)
                }
            )
            .offset(x: rotationHandleOffset.dx, y: rotationHandleOffset.dy)
            .allowsHitTesting(true)
        }
    }

    private func fontForTextBox(_ textBox: TextBox) -> Font {
        let fontName = textBox.fontFamily == "System" ? ".SFUI-Regular" : textBox.fontFamily
        // Scale font size by zoom to render at high resolution
        let scaledFontSize = textBox.fontSize * zoomScale

        if let uiFont = UIFont(name: fontName, size: scaledFontSize) {
            return Font(uiFont)
        } else {
            return .system(size: scaledFontSize)
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

        // Update size to fit final text content while maintaining width (text wraps)
        let newSize = TextBoxUtilities.calculateTextBoxSize(for: editingText, fontSize: textBox.fontSize, fontFamily: textBox.fontFamily, maxWidth: textBox.size.width)
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
}

// Text formatting controls view
struct TextBoxFormattingControls: View {
    @ObservedObject var textBoxManager: TextBoxManager
    @ObservedObject var toolState: ToolState
    @Environment(\.colorScheme) private var colorScheme

    // State for color picker
    @State private var showColorPicker = false
    @State private var newTextColor: Color = .black

    var body: some View {
        let selectedTextBox = textBoxManager.selectedTextBox

        // Use selected textbox properties if available, otherwise use defaults from toolState
        let currentFontFamily = selectedTextBox?.fontFamily ?? toolState.defaultTextBoxFontFamily
        let currentFontSize = selectedTextBox?.fontSize ?? toolState.defaultTextBoxFontSize
        let currentTextAlignment = selectedTextBox?.textAlignment ?? toolState.defaultTextBoxTextAlignment
        let currentTextColor = selectedTextBox?.textColor ?? toolState.defaultTextBoxTextColor
        
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
                        Text(currentFontFamily)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                }

                // Font size controls
                HStack(spacing: 4) {
                    Button(action: { adjustFontSize(-2) }) {
                        Image(systemName: "minus")
                            .font(.caption)
                    }
                    .disabled(currentFontSize <= 8)

                    Text("\(Int(currentFontSize))")
                        .font(.caption)
                        .frame(width: 24)

                    Button(action: { adjustFontSize(2) }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .disabled(currentFontSize >= 72)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)

                // Text alignment buttons
                HStack(spacing: 2) {
                    ForEach(TextAlignment.allCases, id: \.self) { alignment in
                        Button(action: { updateTextAlignment(alignment) }) {
                            Image(systemName: alignmentIcon(for: alignment))
                                .font(.caption)
                                .foregroundColor(currentTextAlignment == alignment ? .blue : .primary)
                        }
                        .frame(width: 24, height: 20)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)

                // Text color
                Button(action: {
                    newTextColor = currentTextColor
                    showColorPicker = true
                }) {
                    Circle()
                        .fill(currentTextColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Color.gray, lineWidth: 1)
                        )
                }
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
        if var selectedTextBox = textBoxManager.selectedTextBox {
            // Editing mode: update the selected textbox
            selectedTextBox.fontFamily = fontFamily

            // Recalculate size to fit text with new font while maintaining width (text wraps)
            let newSize = TextBoxUtilities.calculateTextBoxSize(for: selectedTextBox.text, fontSize: selectedTextBox.fontSize, fontFamily: fontFamily, maxWidth: selectedTextBox.size.width)
            selectedTextBox.size = newSize

            textBoxManager.updateTextBox(selectedTextBox)
        } else {
            // Default mode: update the default font family
            toolState.defaultTextBoxFontFamily = fontFamily
        }
    }

    private func adjustFontSize(_ delta: CGFloat) {
        if var selectedTextBox = textBoxManager.selectedTextBox {
            // Editing mode: update the selected textbox
            selectedTextBox.fontSize = max(8, min(72, selectedTextBox.fontSize + delta))

            // Recalculate size to fit text with new font size while maintaining width (text wraps)
            let newSize = TextBoxUtilities.calculateTextBoxSize(for: selectedTextBox.text, fontSize: selectedTextBox.fontSize, fontFamily: selectedTextBox.fontFamily, maxWidth: selectedTextBox.size.width)
            selectedTextBox.size = newSize

            textBoxManager.updateTextBox(selectedTextBox)
        } else {
            // Default mode: update the default font size
            toolState.defaultTextBoxFontSize = max(8, min(72, toolState.defaultTextBoxFontSize + delta))
        }
    }

    private func updateTextAlignment(_ alignment: TextAlignment) {
        if var selectedTextBox = textBoxManager.selectedTextBox {
            // Editing mode: update the selected textbox
            selectedTextBox.textAlignment = alignment
            textBoxManager.updateTextBox(selectedTextBox)
        } else {
            // Default mode: update the default text alignment
            toolState.defaultTextBoxTextAlignment = alignment
        }
    }

    private func updateTextColor(_ color: Color) {
        if var selectedTextBox = textBoxManager.selectedTextBox {
            // Editing mode: update the selected textbox
            selectedTextBox.textColor = color
            textBoxManager.updateTextBox(selectedTextBox)
        } else {
            // Default mode: update the default text color
            toolState.defaultTextBoxTextColor = color
        }
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
    var zoomScale: CGFloat = 1.0
    let onChanged: (CGSize) -> Void
    let onEnd: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: 18, height: 18)

            Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                .font(.system(size: 9, weight: .medium))
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
