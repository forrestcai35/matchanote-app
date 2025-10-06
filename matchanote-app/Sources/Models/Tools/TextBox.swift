import SwiftUI

// TextBox model for managing text elements on the canvas
struct TextBox: Identifiable, Codable {
    let id: UUID
    var text: String
    var position: CGPoint
    var size: CGSize
    var fontSize: CGFloat
    var fontFamily: String
    var textColor: Color
    var backgroundColor: Color
    var textAlignment: TextAlignment
    var isSelected: Bool
    var rotation: Double
    var opacity: Double
    var cornerRadius: CGFloat
    var borderWidth: CGFloat
    var borderColor: Color

    // Page index this textbox belongs to
    var pageIndex: Int

    init(
        id: UUID = UUID(),
        text: String = "Text",
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 200, height: 60),
        fontSize: CGFloat = 16,
        fontFamily: String = "System",
        textColor: Color = .black,
        backgroundColor: Color = .clear,
        textAlignment: TextAlignment = .leading,
        isSelected: Bool = false,
        rotation: Double = 0,
        opacity: Double = 1.0,
        cornerRadius: CGFloat = 4,
        borderWidth: CGFloat = 0,
        borderColor: Color = .gray,
        pageIndex: Int = 0
    ) {
        self.id = id
        self.text = text
        self.position = position
        self.size = size
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textAlignment = textAlignment
        self.isSelected = isSelected
        self.rotation = rotation
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.pageIndex = pageIndex
    }
}

// Text alignment options
enum TextAlignment: String, CaseIterable, Codable {
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"

    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var textAlignment: SwiftUI.TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// TextBox Manager for handling textboxes across pages
class TextBoxManager: ObservableObject {
    @Published var textBoxesByPage: [Int: [TextBox]] = [:]
    @Published var selectedTextBox: TextBox?
    @Published var isEditingText: Bool = false
    @Published var copiedTextBox: TextBox?
    @Published var editingTextBoxId: UUID?

    // Available font families
    let availableFonts = [
        "System",
        "Helvetica",
        "Helvetica Neue",
        "Arial",
        "Times New Roman",
        "Courier New",
        "Georgia",
        "Verdana",
        "Trebuchet MS",
        "Impact"
    ]

    // Font size presets
    let fontSizePresets: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 60, 72]

    init() {}

    // Add a new textbox to a specific page
    func addTextBox(to pageIndex: Int, at position: CGPoint = CGPoint(x: 100, y: 100)) {
        let newTextBox = TextBox(
            text: "Type here...",
            position: position,
            isSelected: true,
            pageIndex: pageIndex

        )

        if textBoxesByPage[pageIndex] == nil {
            textBoxesByPage[pageIndex] = []
        }
        textBoxesByPage[pageIndex]?.append(newTextBox)

        // Select the new textbox for immediate editing
        selectedTextBox = newTextBox
        isEditingText = true
    }

    // Get textboxes for a specific page
    func textBoxes(for pageIndex: Int) -> [TextBox] {
        return textBoxesByPage[pageIndex] ?? []
    }

    // Update a textbox
    func updateTextBox(_ updatedTextBox: TextBox) {
        guard let pageTextBoxes = textBoxesByPage[updatedTextBox.pageIndex] else { return }

        if let index = pageTextBoxes.firstIndex(where: { $0.id == updatedTextBox.id }) {
            textBoxesByPage[updatedTextBox.pageIndex]?[index] = updatedTextBox

            // Update selected textbox if it matches
            if selectedTextBox?.id == updatedTextBox.id {
                selectedTextBox = updatedTextBox
            }
        }
    }

    // Delete a textbox
    func deleteTextBox(_ textBox: TextBox) {
        guard let pageTextBoxes = textBoxesByPage[textBox.pageIndex] else { return }

        if let index = pageTextBoxes.firstIndex(where: { $0.id == textBox.id }) {
            textBoxesByPage[textBox.pageIndex]?.remove(at: index)

            // Clear selection if this was the selected textbox
            if selectedTextBox?.id == textBox.id {
                selectedTextBox = nil
                isEditingText = false
            }
        }
    }

    // Select a textbox
    func selectTextBox(_ textBox: TextBox) {
        // Deselect all textboxes
        deselectAllTextBoxes()

        // Select the specified textbox
        var updatedTextBox = textBox
        updatedTextBox.isSelected = true
        updateTextBox(updatedTextBox)
        selectedTextBox = updatedTextBox
    }

    // Deselect all textboxes
    func deselectAllTextBoxes() {
        for (pageIndex, textBoxes) in textBoxesByPage {
            for (index, textBox) in textBoxes.enumerated() {
                if textBox.isSelected {
                    textBoxesByPage[pageIndex]?[index].isSelected = false
                }
            }
        }
        selectedTextBox = nil
        isEditingText = false
        editingTextBoxId = nil
    }

    // Move textboxes when pages are inserted/deleted
    func moveTextBoxes(fromPage oldPageIndex: Int, toPage newPageIndex: Int) {
        guard let textBoxes = textBoxesByPage[oldPageIndex] else { return }

        // Update page index for all textboxes
        let updatedTextBoxes = textBoxes.map { textBox in
            var updated = textBox
            updated.pageIndex = newPageIndex
            return updated
        }

        // Move to new page
        textBoxesByPage[newPageIndex] = updatedTextBoxes
        textBoxesByPage[oldPageIndex] = nil
    }

    // Handle page insertion - shift textboxes after insertion point
    func handlePageInsertion(at insertIndex: Int) {
        var newTextBoxesByPage: [Int: [TextBox]] = [:]

        for (pageIndex, textBoxes) in textBoxesByPage {
            let newPageIndex = pageIndex >= insertIndex ? pageIndex + 1 : pageIndex
            let updatedTextBoxes = textBoxes.map { textBox in
                var updated = textBox
                updated.pageIndex = newPageIndex
                return updated
            }
            newTextBoxesByPage[newPageIndex] = updatedTextBoxes
        }

        textBoxesByPage = newTextBoxesByPage
    }

    // Handle page deletion - shift textboxes after deletion point
    func handlePageDeletion(at deletedIndex: Int) {
        var newTextBoxesByPage: [Int: [TextBox]] = [:]

        for (pageIndex, textBoxes) in textBoxesByPage {
            if pageIndex == deletedIndex {
                // Skip deleted page textboxes
                continue
            }

            let newPageIndex = pageIndex > deletedIndex ? pageIndex - 1 : pageIndex
            let updatedTextBoxes = textBoxes.map { textBox in
                var updated = textBox
                updated.pageIndex = newPageIndex
                return updated
            }
            newTextBoxesByPage[newPageIndex] = updatedTextBoxes
        }

        textBoxesByPage = newTextBoxesByPage

        // Clear selection if selected textbox was on deleted page
        if let selected = selectedTextBox, selected.pageIndex == deletedIndex {
            selectedTextBox = nil
            isEditingText = false
        }
    }
    
    // Clear all textboxes from a specific page
    func clearAllTextBoxesFromPage(_ pageIndex: Int) {
        guard let textBoxes = textBoxesByPage[pageIndex], !textBoxes.isEmpty else { return }
        
        // Clear all textboxes from the page
        textBoxesByPage[pageIndex] = []
        
        // Clear selection if selected textbox was on this page
        if let selected = selectedTextBox, selected.pageIndex == pageIndex {
            selectedTextBox = nil
            isEditingText = false
            editingTextBoxId = nil
        }
    }

    // Load textboxes data from storage
    func loadTextBoxesData(_ data: [String: [Data]]) {
        textBoxesByPage.removeAll()

        for (pageKey, dataArray) in data {
            guard let pageIndex = Int(pageKey) else { continue }

            var textBoxes: [TextBox] = []
            for data in dataArray {
                if let textBox = try? JSONDecoder().decode(TextBox.self, from: data) {
                    textBoxes.append(textBox)
                }
            }

            if !textBoxes.isEmpty {
                textBoxesByPage[pageIndex] = textBoxes
            }
        }
    }

    // Get all textboxes data for storage
    func getAllTextBoxesData() -> [String: [Data]] {
        var result: [String: [Data]] = [:]

        for (pageIndex, textBoxes) in textBoxesByPage {
            let pageKey = String(pageIndex)
            var dataArray: [Data] = []

            for textBox in textBoxes {
                if let data = try? JSONEncoder().encode(textBox) {
                    dataArray.append(data)
                }
            }

            if !dataArray.isEmpty {
                result[pageKey] = dataArray
            }
        }

        return result
    }
}

// Make Color conform to Codable for TextBox storage
extension Color: Codable {
    private struct ColorComponents: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let components = try container.decode(ColorComponents.self)
        self = Color(.sRGB, red: components.red, green: components.green, blue: components.blue, opacity: components.alpha)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        #if os(macOS)
        let nsColor = NSColor(self)
        let ciColor = CIColor(color: nsColor) ?? CIColor(red: 0, green: 0, blue: 0, alpha: 1)
        #else
        let uiColor = UIColor(self)
        let ciColor = CIColor(color: uiColor)
        #endif

        let components = ColorComponents(
            red: Double(ciColor.red),
            green: Double(ciColor.green),
            blue: Double(ciColor.blue),
            alpha: Double(ciColor.alpha)
        )

        try container.encode(components)
    }
}
