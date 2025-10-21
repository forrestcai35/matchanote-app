import SwiftUI

// TextBox model for managing text elements on the canvas
public struct TextBox: Identifiable, Codable {
    public let id: UUID
    public var text: String
    public var position: CGPoint
    public var size: CGSize
    public var fontSize: CGFloat
    public var fontFamily: String
    public var textColor: Color
    public var backgroundColor: Color
    public var textAlignment: TextAlignment
    public var rotation: Double
    public var opacity: Double
    public var cornerRadius: CGFloat
    public var borderWidth: CGFloat
    public var borderColor: Color
    public var zIndex: Int

    // Page index this textbox belongs to
    public var pageIndex: Int

    public init(
        id: UUID = UUID(),
        text: String = "Text",
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 200, height: 60),
        fontSize: CGFloat = 16,
        fontFamily: String = "System",
        textColor: Color = .black,
        backgroundColor: Color = .clear,
        textAlignment: TextAlignment = .leading,
        rotation: Double = 0,
        opacity: Double = 1.0,
        cornerRadius: CGFloat = 4,
        borderWidth: CGFloat = 0,
        borderColor: Color = .gray,
        zIndex: Int = 0,
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
        self.rotation = rotation
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.zIndex = zIndex
        self.pageIndex = pageIndex
    }

    // Helper method to check if a point is inside the textbox
    public func contains(point: CGPoint) -> Bool {
        let frame = CGRect(origin: position, size: size)
        return frame.contains(point)
    }
}

// Text alignment options
public enum TextAlignment: String, CaseIterable, Codable {
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"

    public var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    public var alignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    public var textAlignment: SwiftUI.TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// TextBox Manager for handling textboxes across pages
public class TextBoxManager: ObservableObject {
    @Published public var textBoxesByPage: [Int: [TextBox]] = [:]
    @Published public var selectedTextBoxId: UUID?
    @Published public var isEditingText: Bool = false
    @Published public var copiedTextBox: TextBox?
    @Published public var editingTextBoxId: UUID?
    @Published public var currentEditingText: String = "" // Track current text being edited

    // Available font families
    public let availableFonts = [
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
    public let fontSizePresets: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 60, 72]

    public init() {}

    // Add a new textbox to a specific page
    public func addTextBox(to pageIndex: Int, at position: CGPoint = CGPoint(x: 100, y: 100)) {
        let defaultSize = CGSize(width: 200, height: 60)
        // Center the textbox at the tap position
        let centeredPosition = CGPoint(
            x: position.x - defaultSize.width / 2,
            y: position.y - defaultSize.height / 2
        )
        
        let newTextBox = TextBox(
            text: "",
            position: centeredPosition,
            pageIndex: pageIndex
        )

        if textBoxesByPage[pageIndex] == nil {
            textBoxesByPage[pageIndex] = []
        }
        textBoxesByPage[pageIndex]?.append(newTextBox)

        // Select the new textbox for immediate editing
        selectedTextBoxId = newTextBox.id
        editingTextBoxId = newTextBox.id
        isEditingText = true
    }

    // Get textboxes for a specific page
    public func textBoxes(for pageIndex: Int) -> [TextBox] {
        return textBoxesByPage[pageIndex] ?? []
    }

    // Get a specific textbox by ID
    public func getTextBox(withId id: UUID, onPage pageIndex: Int) -> TextBox? {
        return textBoxesByPage[pageIndex]?.first { $0.id == id }
    }

    // Update a textbox
    public func updateTextBox(_ updatedTextBox: TextBox) {
        guard let pageTextBoxes = textBoxesByPage[updatedTextBox.pageIndex] else { return }

        if let index = pageTextBoxes.firstIndex(where: { $0.id == updatedTextBox.id }) {
            textBoxesByPage[updatedTextBox.pageIndex]?[index] = updatedTextBox
        }
    }

    // Delete a textbox
    public func deleteTextBox(withId id: UUID, fromPage pageIndex: Int) {
        guard let pageTextBoxes = textBoxesByPage[pageIndex] else { return }

        if let index = pageTextBoxes.firstIndex(where: { $0.id == id }) {
            textBoxesByPage[pageIndex]?.remove(at: index)

            // Clear selection if this was the selected textbox
            if selectedTextBoxId == id {
                selectedTextBoxId = nil
                isEditingText = false
                editingTextBoxId = nil
            }
        }
    }

    // Select a textbox
    public func selectTextBox(withId id: UUID?) {
        selectedTextBoxId = id
    }

    // Deselect all textboxes
    public func deselectAllTextBoxes() {
        // Before deselecting, check if the currently selected textbox has any text
        if let selectedId = selectedTextBoxId, let selectedBox = selectedTextBox {
            // Use currentEditingText if actively editing, otherwise use saved text
            let textToCheck = isEditingText ? currentEditingText : selectedBox.text
            
            // Delete if text is empty or only whitespace
            let hasNoText = textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            if hasNoText {
                // Remove the empty textbox
                deleteTextBox(withId: selectedId, fromPage: selectedBox.pageIndex)
            }
        }
        
        selectedTextBoxId = nil
        isEditingText = false
        editingTextBoxId = nil
        currentEditingText = ""
    }

    // Check if there's a selected textbox
    public var hasSelectedTextBox: Bool {
        selectedTextBoxId != nil
    }

    // Get the currently selected textbox
    public var selectedTextBox: TextBox? {
        guard let id = selectedTextBoxId else { return nil }
        for (_, textBoxes) in textBoxesByPage {
            if let textBox = textBoxes.first(where: { $0.id == id }) {
                return textBox
            }
        }
        return nil
    }

    // Move textboxes when pages are inserted/deleted
    public func moveTextBoxes(fromPage oldPageIndex: Int, toPage newPageIndex: Int) {
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
    public func handlePageInsertion(at insertIndex: Int) {
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
    public func handlePageDeletion(at deletedIndex: Int) {
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
        if let selectedId = selectedTextBoxId {
            // Check if the selected textbox was on the deleted page
            var wasOnDeletedPage = false
            if let textBoxes = textBoxesByPage[deletedIndex] {
                wasOnDeletedPage = textBoxes.contains(where: { $0.id == selectedId })
            }
            if wasOnDeletedPage {
                selectedTextBoxId = nil
                isEditingText = false
                editingTextBoxId = nil
            }
        }
    }

    // Clear all textboxes from a specific page
    public func clearAllTextBoxesFromPage(_ pageIndex: Int) {
        guard let textBoxes = textBoxesByPage[pageIndex], !textBoxes.isEmpty else { return }

        // Clear all textboxes from the page
        textBoxesByPage[pageIndex] = []

        // Clear selection if selected textbox was on this page
        if let selectedId = selectedTextBoxId {
            let wasOnPage = textBoxes.contains(where: { $0.id == selectedId })
            if wasOnPage {
                selectedTextBoxId = nil
                isEditingText = false
                editingTextBoxId = nil
            }
        }
    }

    // Load textboxes data from storage
    public func loadTextBoxesData(_ data: [String: [Data]]) {
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
    public func getAllTextBoxesData() -> [String: [Data]] {
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

    // Hit testing - find textbox at a point
    public func textBoxAt(point: CGPoint, onPage pageIndex: Int) -> TextBox? {
        let textBoxes = self.textBoxes(for: pageIndex)
        // Return the topmost textbox (highest zIndex) that contains the point
        return textBoxes
            .filter { $0.contains(point: point) }
            .max { $0.zIndex < $1.zIndex }
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
