import SwiftUI

struct TextBoxOverlay: View {
    @ObservedObject var textBoxManager: TextBoxManager
    let pageIndex: Int
    let canvasSize: CGSize
    @State private var dragOffset: CGSize = .zero
    @State private var tempPosition: CGPoint = .zero

    var body: some View {
        ZStack {
            // Textboxes for this page
            ForEach(textBoxManager.textBoxes(for: pageIndex)) { textBox in
                TextBoxView(
                    textBox: textBox,
                    textBoxManager: textBoxManager,
                    canvasSize: canvasSize
                )
                .position(
                    x: textBox.position.x + textBox.size.width / 2,
                    y: textBox.position.y + textBox.size.height / 2
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .contentShape(Rectangle())
        .onTapGesture {
            // Only deselect textboxes when textbox tool is active
            // This allows other tools to work properly
            // (The tool check should be done in the parent view)
            textBoxManager.deselectAllTextBoxes()
        }
        .allowsHitTesting(true) // Allow hit testing but don't interfere with other tools
    }
}

struct TextBoxView: View {
    @State var textBox: TextBox
    @ObservedObject var textBoxManager: TextBoxManager
    let canvasSize: CGSize
    @State private var dragOffset: CGSize = .zero
    @State private var isEditing: Bool = false
    @State private var editingText: String = ""
    @State private var resizeOffset: CGSize = .zero

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
                Text(textBox.text.isEmpty ? "Tap to edit" : textBox.text)
                    .font(fontForTextBox(textBox))
                    .foregroundColor(textBox.text.isEmpty ? .gray : textBox.textColor)
                    .multilineTextAlignment(textBox.textAlignment.textAlignment)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: textBox.textAlignment.alignment)
            }

            // Selection border and resize handles
            if textBox.isSelected && !isEditing {
                // Selection border
                RoundedRectangle(cornerRadius: textBox.cornerRadius)
                    .stroke(Color.blue, lineWidth: 2)
                    .background(Color.clear)

                // Resize handles
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        // Bottom-right resize handle
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .offset(x: 6, y: 6)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        resizeOffset = value.translation
                                    }
                                    .onEnded { value in
                                        let newWidth = max(100, textBox.size.width + value.translation.width)
                                        let newHeight = max(40, textBox.size.height + value.translation.height)

                                        var updatedTextBox = textBox
                                        updatedTextBox.size = CGSize(width: newWidth, height: newHeight)
                                        textBoxManager.updateTextBox(updatedTextBox)
                                        textBox = updatedTextBox
                                        resizeOffset = .zero
                                    }
                            )
                    }
                }

                // Right edge resize handle (horizontal only)
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    resizeOffset = CGSize(width: value.translation.width, height: 0)
                                }
                                .onEnded { value in
                                    let newWidth = max(100, textBox.size.width + value.translation.width)

                                    var updatedTextBox = textBox
                                    updatedTextBox.size = CGSize(width: newWidth, height: textBox.size.height)
                                    textBoxManager.updateTextBox(updatedTextBox)
                                    textBox = updatedTextBox
                                    resizeOffset = .zero
                                }
                        )
                }
            }
        }
        .frame(width: textBox.size.width, height: textBox.size.height)
        .opacity(textBox.opacity)
        .rotationEffect(.degrees(textBox.rotation))
        .offset(dragOffset)
        .onTapGesture {
            if !textBox.isSelected {
                textBoxManager.selectTextBox(textBox)
            } else if textBox.isSelected && !isEditing {
                startEditing()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if textBox.isSelected && !isEditing {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if textBox.isSelected && !isEditing {
                        let newPosition = CGPoint(
                            x: max(0, min(canvasSize.width - textBox.size.width, textBox.position.x + value.translation.width)),
                            y: max(0, min(canvasSize.height - textBox.size.height, textBox.position.y + value.translation.height))
                        )

                        var updatedTextBox = textBox
                        updatedTextBox.position = newPosition
                        textBoxManager.updateTextBox(updatedTextBox)
                        textBox = updatedTextBox
                        dragOffset = .zero
                    }
                }
        )
        .onChange(of: textBoxManager.editingTextBoxId) { _, newId in
            if newId == textBox.id && textBoxManager.isEditingText {
                startEditing()
            }
        }
        .contextMenu {
            Button("Edit Text") {
                startEditing()
            }
            Divider()
            Button("Cut") {
                copyTextBox()
                textBoxManager.deleteTextBox(textBox)
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
                textBoxManager.deleteTextBox(textBox)
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
        textBox = updatedTextBox
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
            isSelected: false,
            rotation: textBox.rotation,
            opacity: textBox.opacity,
            cornerRadius: textBox.cornerRadius,
            borderWidth: textBox.borderWidth,
            borderColor: textBox.borderColor,
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
            isSelected: false,
            rotation: copiedTextBox.rotation,
            opacity: copiedTextBox.opacity,
            cornerRadius: copiedTextBox.cornerRadius,
            borderWidth: copiedTextBox.borderWidth,
            borderColor: copiedTextBox.borderColor,
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
        guard let selectedTextBox = textBoxManager.selectedTextBox else {
            return AnyView(Text("Select a textbox to edit").font(.caption).foregroundColor(.gray))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Edit text button
                    Button(action: {
                        if let selectedTextBox = textBoxManager.selectedTextBox {
                            textBoxManager.editingTextBoxId = selectedTextBox.id
                            textBoxManager.isEditingText = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("Edit")
                                .font(.caption)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }

                    // Font family dropdown
                    Menu {
                        ForEach(textBoxManager.availableFonts, id: \.self) { font in
                            Button(font) {
                                updateTextBoxFont(font)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedTextBox.fontFamily)
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
                        .disabled(selectedTextBox.fontSize <= 8)

                        Text("\(Int(selectedTextBox.fontSize))")
                            .font(.caption)
                            .frame(width: 24)

                        Button(action: { adjustFontSize(2) }) {
                            Image(systemName: "plus")
                                .font(.caption)
                        }
                        .disabled(selectedTextBox.fontSize >= 72)
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
                                    .foregroundColor(selectedTextBox.textAlignment == alignment ? .blue : .primary)
                            }
                            .frame(width: 24, height: 20)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)

                    // Text color
                    Button(action: { showColorPicker = true }) {
                        Circle()
                            .fill(selectedTextBox.textColor)
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
        )
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