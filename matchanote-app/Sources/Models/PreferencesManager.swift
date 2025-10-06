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

    // Enabled AI models (by display name)
    @Published var enabledModels: Set<String> {
        didSet {
            userDefaults.set(Array(enabledModels), forKey: DefaultsKeys.enabledModels)
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
        
        // Load enabled models or default to enabling all known models
        if let savedModels = userDefaults.array(forKey: DefaultsKeys.enabledModels) as? [String] {
            self.enabledModels = Set(savedModels)
        } else {
            self.enabledModels = Set(ModelConfiguration.allModels.map { $0.displayName })
        }
    }
    
    // MARK: - Public Methods
    func resetToDefaults() {
        assistantDefaultOrientation = .left
        theme = .system
        supabaseStorageEnabled = false
        enabledModels = Set(ModelConfiguration.allModels.map { $0.displayName })
    }

    // MARK: - Model Enablement Helpers
    func isModelEnabled(_ displayName: String) -> Bool {
        return enabledModels.contains(displayName)
    }

    func setModel(_ displayName: String, enabled: Bool) {
        var updated = enabledModels
        if enabled {
            updated.insert(displayName)
        } else {
            updated.remove(displayName)
        }
        enabledModels = updated
    }
}
