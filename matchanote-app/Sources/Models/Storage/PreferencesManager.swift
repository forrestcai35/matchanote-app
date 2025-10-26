import Foundation
import SwiftUI

// MARK: - Assistant Orientation enum
enum AssistantOrientation: String, CaseIterable {
    case left = "left"
    case right = "right"

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

// MARK: - App Theme enum
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Undo/Redo Gesture Mode enum
enum UndoRedoGestureMode: String, CaseIterable {
    case threeFingerSwipe = "threeFingerSwipe"
    case twoThreeTap = "twoThreeTap"

    var displayName: String {
        switch self {
        case .threeFingerSwipe: return "3-Finger Swipe"
        case .twoThreeTap: return "2-Tap/3-Tap"
        }
    }
    
    var description: String {
        switch self {
        case .threeFingerSwipe: return "Swipe left/right with 3 fingers to undo/redo"
        case .twoThreeTap: return "2-finger tap to undo, 3-finger tap to redo"
        }
    }
}

// MARK: - Preferences Manager
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum DefaultsKeys {
        static let assistantDefaultOrientation = "preferences.assistantDefaultOrientation"
        static let theme = "preferences.theme"
        static let supabaseStorageEnabled = "preferences.supabaseStorageEnabled"
        static let enabledModels = "preferences.enabledModels"
        static let modelOrder = "preferences.modelOrder"
        
        // Note Editor Preferences
        static let noteEditorStatusBarHidden = "preferences.noteEditor.statusBarHidden"
        static let noteEditorFingerDrawingEnabled = "preferences.noteEditor.fingerDrawingEnabled"
        static let noteEditorLeftHandMode = "preferences.noteEditor.leftHandMode"
        static let noteEditorUndoRedoGestureMode = "preferences.noteEditor.undoRedoGestureMode"
        static let noteEditorToolsOrder = "preferences.noteEditor.tools.order"
        static let noteEditorToolPen = "preferences.noteEditor.tools.pen"
        static let noteEditorToolMarker = "preferences.noteEditor.tools.marker"
        static let noteEditorToolEraser = "preferences.noteEditor.tools.eraser"
        static let noteEditorToolLasso = "preferences.noteEditor.tools.lasso"
        static let noteEditorToolPhoto = "preferences.noteEditor.tools.photo"
        static let noteEditorToolTextbox = "preferences.noteEditor.tools.textbox"
        static let noteEditorToolShape = "preferences.noteEditor.tools.shape"
        static let noteEditorVerticalScrollMode = "preferences.noteEditor.verticalScrollMode"
        static let noteEditorPageBoundaryIndicators = "preferences.noteEditor.pageBoundaryIndicators"
    }
    
    // MARK: - Published Properties
    @Published var assistantDefaultOrientation: AssistantOrientation {
        didSet {
            userDefaults.set(assistantDefaultOrientation.rawValue, forKey: DefaultsKeys.assistantDefaultOrientation)
        }
    }

    @Published var theme: AppTheme {
        didSet {
            userDefaults.set(theme.rawValue, forKey: DefaultsKeys.theme)
        }
    }
    
    @Published var supabaseStorageEnabled: Bool {
        didSet {
            userDefaults.set(supabaseStorageEnabled, forKey: DefaultsKeys.supabaseStorageEnabled)
        }
    }

    // Enabled AI models (by model ID for robustness)
    @Published var enabledModelIds: Set<String> {
        didSet {
            userDefaults.set(Array(enabledModelIds), forKey: DefaultsKeys.enabledModels)
        }
    }
    
    // Model order (comma-separated list of model IDs)
    @Published var modelOrderIds: [String] {
        didSet {
            userDefaults.set(modelOrderIds.joined(separator: ","), forKey: DefaultsKeys.modelOrder)
        }
    }
    
    // MARK: - Note Editor Preferences
    @Published var noteEditorStatusBarHidden: Bool {
        didSet {
            userDefaults.set(noteEditorStatusBarHidden, forKey: DefaultsKeys.noteEditorStatusBarHidden)
        }
    }
    
    @Published var noteEditorFingerDrawingEnabled: Bool {
        didSet {
            userDefaults.set(noteEditorFingerDrawingEnabled, forKey: DefaultsKeys.noteEditorFingerDrawingEnabled)
        }
    }
    
    @Published var noteEditorLeftHandMode: Bool {
        didSet {
            userDefaults.set(noteEditorLeftHandMode, forKey: DefaultsKeys.noteEditorLeftHandMode)
        }
    }
    
    @Published var noteEditorUndoRedoGestureMode: UndoRedoGestureMode {
        didSet {
            userDefaults.set(noteEditorUndoRedoGestureMode.rawValue, forKey: DefaultsKeys.noteEditorUndoRedoGestureMode)
        }
    }
    
    @Published var noteEditorToolsOrder: [String] {
        didSet {
            userDefaults.set(noteEditorToolsOrder.joined(separator: ","), forKey: DefaultsKeys.noteEditorToolsOrder)
        }
    }
    
    @Published var noteEditorToolPen: Bool {
        didSet {
            userDefaults.set(noteEditorToolPen, forKey: DefaultsKeys.noteEditorToolPen)
        }
    }
    
    @Published var noteEditorToolMarker: Bool {
        didSet {
            userDefaults.set(noteEditorToolMarker, forKey: DefaultsKeys.noteEditorToolMarker)
        }
    }
    
    @Published var noteEditorToolEraser: Bool {
        didSet {
            userDefaults.set(noteEditorToolEraser, forKey: DefaultsKeys.noteEditorToolEraser)
        }
    }
    
    @Published var noteEditorToolLasso: Bool {
        didSet {
            userDefaults.set(noteEditorToolLasso, forKey: DefaultsKeys.noteEditorToolLasso)
        }
    }
    
    @Published var noteEditorToolPhoto: Bool {
        didSet {
            userDefaults.set(noteEditorToolPhoto, forKey: DefaultsKeys.noteEditorToolPhoto)
        }
    }
    
    @Published var noteEditorToolTextbox: Bool {
        didSet {
            userDefaults.set(noteEditorToolTextbox, forKey: DefaultsKeys.noteEditorToolTextbox)
        }
    }
    
    @Published var noteEditorToolShape: Bool {
        didSet {
            userDefaults.set(noteEditorToolShape, forKey: DefaultsKeys.noteEditorToolShape)
        }
    }
    
    @Published var noteEditorVerticalScrollMode: Bool {
        didSet {
            userDefaults.set(noteEditorVerticalScrollMode, forKey: DefaultsKeys.noteEditorVerticalScrollMode)
        }
    }
    
    @Published var noteEditorPageBoundaryIndicators: Bool {
        didSet {
            userDefaults.set(noteEditorPageBoundaryIndicators, forKey: DefaultsKeys.noteEditorPageBoundaryIndicators)
        }
    }

    
    private init() {
        // Load saved orientation or default to left
        let savedOrientation = userDefaults.string(forKey: DefaultsKeys.assistantDefaultOrientation)
        self.assistantDefaultOrientation = AssistantOrientation(rawValue: savedOrientation ?? "left") ?? .left

        // Load saved theme or default to system
        let savedTheme = userDefaults.string(forKey: DefaultsKeys.theme)
        self.theme = AppTheme(rawValue: savedTheme ?? "system") ?? .system
        
        // Load saved Supabase storage preference or default to false (disabled)
        self.supabaseStorageEnabled = userDefaults.bool(forKey: DefaultsKeys.supabaseStorageEnabled)
        
        // Load note editor preferences
        self.noteEditorStatusBarHidden = userDefaults.bool(forKey: DefaultsKeys.noteEditorStatusBarHidden)
        
        // Load finger drawing preference or default to false (pencil only)
        self.noteEditorFingerDrawingEnabled = userDefaults.object(forKey: DefaultsKeys.noteEditorFingerDrawingEnabled) as? Bool ?? false
        
        // Load left hand mode preference or default to false (right-handed)
        self.noteEditorLeftHandMode = userDefaults.object(forKey: DefaultsKeys.noteEditorLeftHandMode) as? Bool ?? false
        
        // Load undo/redo gesture mode or default to three finger swipe
        let savedGestureMode = userDefaults.string(forKey: DefaultsKeys.noteEditorUndoRedoGestureMode)
        self.noteEditorUndoRedoGestureMode = UndoRedoGestureMode(rawValue: savedGestureMode ?? "threeFingerSwipe") ?? .threeFingerSwipe
  
        // Load tools order or default to all tools in their default order
        if let savedToolsOrder = userDefaults.string(forKey: DefaultsKeys.noteEditorToolsOrder) {
            self.noteEditorToolsOrder = savedToolsOrder.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } else {
            self.noteEditorToolsOrder = ["pen", "marker", "eraser", "lasso", "photo", "textbox", "shape"]
        }
        
        // Load tool visibility preferences or default to all enabled
        self.noteEditorToolPen = userDefaults.object(forKey: DefaultsKeys.noteEditorToolPen) as? Bool ?? true
        self.noteEditorToolMarker = userDefaults.object(forKey: DefaultsKeys.noteEditorToolMarker) as? Bool ?? true
        self.noteEditorToolEraser = userDefaults.object(forKey: DefaultsKeys.noteEditorToolEraser) as? Bool ?? true
        self.noteEditorToolLasso = userDefaults.object(forKey: DefaultsKeys.noteEditorToolLasso) as? Bool ?? true
        self.noteEditorToolPhoto = userDefaults.object(forKey: DefaultsKeys.noteEditorToolPhoto) as? Bool ?? true
        self.noteEditorToolTextbox = userDefaults.object(forKey: DefaultsKeys.noteEditorToolTextbox) as? Bool ?? true
        self.noteEditorToolShape = userDefaults.object(forKey: DefaultsKeys.noteEditorToolShape) as? Bool ?? true
        
        // Load vertical scroll mode preference or default to false (page mode)
        self.noteEditorVerticalScrollMode = userDefaults.object(forKey: DefaultsKeys.noteEditorVerticalScrollMode) as? Bool ?? false
        
        // Load page boundary indicators preference or default to true (enabled)
        self.noteEditorPageBoundaryIndicators = userDefaults.object(forKey: DefaultsKeys.noteEditorPageBoundaryIndicators) as? Bool ?? true
        
        // Load enabled models with dynamic model management
        if let savedModels = userDefaults.array(forKey: DefaultsKeys.enabledModels) as? [String] {
            // Check if we have old display names or new model IDs
            let allModelIds = Set(ModelConfiguration.allModels.map { $0.modelId })
            let allDisplayNames = Set(ModelConfiguration.allModels.map { $0.displayName })
            
            let migratedIds: Set<String>
            if savedModels.allSatisfy({ allModelIds.contains($0) }) {
                // New format: model IDs
                migratedIds = Set(savedModels)
            } else if savedModels.allSatisfy({ allDisplayNames.contains($0) }) {
                // Old format: display names - migrate to model IDs
                migratedIds = Set(savedModels.compactMap { displayName in
                    ModelConfiguration.allModels.first { $0.displayName == displayName }?.modelId
                })
            } else {
                // Mixed or invalid - reset to defaults
                migratedIds = Set(ModelConfiguration.allModels.map { $0.modelId })
            }
            
            // Filter to only include models that still exist
            let filteredIds = migratedIds.intersection(allModelIds)
            
            // If no models are enabled (all were removed), enable all current models
            if filteredIds.isEmpty {
                self.enabledModelIds = allModelIds
            } else {
                self.enabledModelIds = filteredIds
            }
        } else {
            self.enabledModelIds = Set(ModelConfiguration.allModels.map { $0.modelId })
        }
        
        // Load model order with dynamic model management
        if let savedOrder = userDefaults.string(forKey: DefaultsKeys.modelOrder) {
            let rawOrder = savedOrder.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            
            // Check if we have old display names or new model IDs
            let allModelIds = Set(ModelConfiguration.allModels.map { $0.modelId })
            let allDisplayNames = Set(ModelConfiguration.allModels.map { $0.displayName })
            
            let migratedOrder: [String]
            if rawOrder.allSatisfy({ allModelIds.contains($0) }) {
                // New format: model IDs
                migratedOrder = rawOrder
            } else if rawOrder.allSatisfy({ allDisplayNames.contains($0) }) {
                // Old format: display names - migrate to model IDs
                migratedOrder = rawOrder.compactMap { displayName in
                    ModelConfiguration.allModels.first { $0.displayName == displayName }?.modelId
                }
            } else {
                // Mixed or invalid - reset to defaults
                migratedOrder = ModelConfiguration.allModels.map { $0.modelId }
            }
            
            // Filter to only include models that still exist, maintain order
            self.modelOrderIds = migratedOrder.filter { allModelIds.contains($0) }
            
            // Add any new models that weren't in the saved order (append to end)
            let newModels = allModelIds.subtracting(Set(migratedOrder))
            self.modelOrderIds.append(contentsOf: newModels)
        } else {
            self.modelOrderIds = ModelConfiguration.allModels.map { $0.modelId }
        }
        
        // Ensure at least one model is always enabled (after all properties are initialized)
        if self.enabledModelIds.isEmpty {
            self.enabledModelIds = Set([ModelConfiguration.allModels.first?.modelId ?? ""])
        }
        
    }
    
    
    // MARK: - Public Methods
    func resetToDefaults() {
        assistantDefaultOrientation = .right
        theme = .system
        supabaseStorageEnabled = false
        enabledModelIds = Set(ModelConfiguration.allModels.map { $0.modelId })
        modelOrderIds = ModelConfiguration.allModels.map { $0.modelId }
    }
    

    // MARK: - Model Enablement Helpers
    func isModelEnabled(_ displayName: String) -> Bool {
        guard let modelId = ModelConfiguration.getModelId(for: displayName) else { return false }
        return enabledModelIds.contains(modelId)
    }

    func setModel(_ displayName: String, enabled: Bool) {
        guard let modelId = ModelConfiguration.getModelId(for: displayName) else { return }
        
        // Prevent disabling the last model
        if !enabled && !canDisableModel(displayName) {
            print("🚫 Cannot disable model '\(displayName)' - it's the last enabled model")
            return
        }
        
        var updated = enabledModelIds
        if enabled {
            updated.insert(modelId)
        } else {
            updated.remove(modelId)
        }
        
        // Safety check: ensure we never end up with zero enabled models
        if updated.isEmpty {
            print("⚠️ Attempted to disable all models, keeping at least one enabled")
            return
        }
        
        enabledModelIds = updated
        print("✅ Model '\(displayName)' \(enabled ? "enabled" : "disabled"). Enabled models: \(Array(updated))")
    }
    
    // MARK: - Model Order Helpers
    func getOrderedEnabledModels() -> [String] {
        return modelOrderIds.compactMap { modelId in
            ModelConfiguration.allModels.first { $0.modelId == modelId }?.displayName
        }.filter { displayName in
            isModelEnabled(displayName)
        }
    }
    
    func getAllOrderedModels() -> [String] {
        return modelOrderIds.compactMap { modelId in
            ModelConfiguration.allModels.first { $0.modelId == modelId }?.displayName
        }
    }
    
    func updateModelOrder(_ newOrder: [String]) {
        // Convert display names to model IDs
        let modelIds = newOrder.compactMap { displayName in
            ModelConfiguration.getModelId(for: displayName)
        }
        modelOrderIds = modelIds
    }
    
    // MARK: - Note Editor Helpers
    func isToolEnabled(_ toolId: String) -> Bool {
        switch toolId {
        case "pen": return noteEditorToolPen
        case "marker": return noteEditorToolMarker
        case "eraser": return noteEditorToolEraser
        case "lasso": return noteEditorToolLasso
        case "photo": return noteEditorToolPhoto
        case "textbox": return noteEditorToolTextbox
        case "shape": return noteEditorToolShape
        default: return false
        }
    }
    
    func setTool(_ toolId: String, enabled: Bool) {
        // Prevent disabling the last tool
        if !enabled && !canDisableTool(toolId) {
            return
        }
        
        switch toolId {
        case "pen": noteEditorToolPen = enabled
        case "marker": noteEditorToolMarker = enabled
        case "eraser": noteEditorToolEraser = enabled
        case "lasso": noteEditorToolLasso = enabled
        case "photo": noteEditorToolPhoto = enabled
        case "textbox": noteEditorToolTextbox = enabled
        case "shape": noteEditorToolShape = enabled
        default: break
        }
    }
    
    func updateToolsOrder(_ newOrder: [String]) {
        noteEditorToolsOrder = newOrder
    }
    
    func getOrderedEnabledTools() -> [String] {
        return noteEditorToolsOrder.filter { isToolEnabled($0) }
    }
    
    // MARK: - Constraint Helpers
    func canDisableModel(_ displayName: String) -> Bool {
        // Get the all enabled models 
        let orderedEnabled = getOrderedEnabledModels()
        let canDisable = orderedEnabled.count > 1 || !orderedEnabled.contains(displayName)
        print("🔍 canDisableModel('\(displayName)'): orderedEnabled=\(orderedEnabled), count=\(orderedEnabled.count), canDisable=\(canDisable)")
        return canDisable
    }
    
    func canDisableTool(_ toolId: String) -> Bool {
        let enabledTools = getOrderedEnabledTools()
        return enabledTools.count > 1 || !isToolEnabled(toolId)
    }
}
