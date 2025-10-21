import SwiftUI

struct TextBoxOverlay: View {
    @ObservedObject var textBoxManager: TextBoxManager
    let pageIndex: Int
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Background tap to deselect - only intercept when there's a selection or editing
            if textBoxManager.hasSelectedTextBox || textBoxManager.isEditingText {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        textBoxManager.deselectAllTextBoxes()
                    }
            }

            // Textboxes for this page
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
        .allowsHitTesting(textBoxManager.textBoxes(for: pageIndex).count > 0)
    }
}

struct TextBoxView: View {
    let textBox: TextBox
    @ObservedObject var textBoxManager: TextBoxManager
    let pageIndex: Int
    let canvasSize: CGSize

    @State private var dragOffset: CGSize = .zero
    @State private var isEditing: Bool = false
    @State private var editingText: String = ""
    @State private var currentSize: CGSize = .zero

    var isSelected: Bool {
        textBoxManager.selectedTextBoxId == textBox.id
    }

    var body: some View {
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
                TextField("Enter text", text: $editingText, axis: .vertical)
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
            } else {
                // Non-interactive text display
                Text(textBox.text.isEmpty ? "Tap to edit" : textBox.text)
                    .font(fontForTextBox(textBox))
                    .foregroundColor(textBox.text.isEmpty ? .gray : textBox.textColor)
                    .multilineTextAlignment(textBox.textAlignment.textAlignment)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: textBox.textAlignment.alignment)
            }

            // Selection controls
            if isSelected && !isEditing {
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
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if isSelected && !isEditing {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if isSelected && !isEditing {
                        let newPosition = CGPoint(
                            x: max(0, min(canvasSize.width - textBox.size.width, textBox.position.x + value.translation.width)),
                            y: max(0, min(canvasSize.height - textBox.size.height, textBox.position.y + value.translation.height))
                        )

                        var updatedTextBox = textBox
                        updatedTextBox.position = newPosition
                        textBoxManager.updateTextBox(updatedTextBox)
                    }
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            // Don't process tap if we just dragged
            if dragOffset == .zero {
                if !isSelected {
                    textBoxManager.selectTextBox(withId: textBox.id)
                } else if !isEditing {
                    startEditing()
                }
            }
        }
        .onChange(of: textBoxManager.editingTextBoxId) { _, newId in
            if newId == textBox.id && textBoxManager.isEditingText {
                startEditing()
            } else if newId != textBox.id && isEditing {
                finishEditing()
            }
        }
        .onChange(of: textBoxManager.selectedTextBoxId) { _, newId in
            if newId != textBox.id && isEditing {
                isEditing = false
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

            // Corner handle - proportional scaling (bottom-right)
            ProportionalResizeHandle(
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

            // Right edge resize handle (horizontal only)
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = max(100, textBox.size.width + value.translation.width)
                                currentSize = CGSize(width: newWidth, height: textBox.size.height)
                            }
                            .onEnded { value in
                                if currentSize.width > 0 {
                                    var updatedTextBox = textBox
                                    updatedTextBox.size = currentSize
                                    textBoxManager.updateTextBox(updatedTextBox)
                                }
                                currentSize = .zero
                            }
                    )
            }
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
        isEditing = true
        editingText = textBox.text
        textBoxManager.isEditingText = true
        textBoxManager.editingTextBoxId = textBox.id
    }

    private func finishEditing() {
        isEditing = false
        textBoxManager.isEditingText = false
        textBoxManager.editingTextBoxId = nil

        var updatedTextBox = textBox
        updatedTextBox.text = editingText
        textBoxManager.updateTextBox(updatedTextBox)
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
        textBoxManager.updateTextBox(selectedTextBox)
    }

    private func adjustFontSize(_ delta: CGFloat) {
        guard var selectedTextBox = textBoxManager.selectedTextBox else { return }
        selectedTextBox.fontSize = max(8, min(72, selectedTextBox.fontSize + delta))
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