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

// MARK: - Preferences Manager
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum DefaultsKeys {
        static let assistantDefaultOrientation = "preferences.assistantDefaultOrientation"
    }
    
    // MARK: - Published Properties
    @Published var assistantDefaultOrientation: AssistantOrientation {
        didSet {
            userDefaults.set(assistantDefaultOrientation.rawValue, forKey: DefaultsKeys.assistantDefaultOrientation)
        }
    }
    
    private init() {
        // Load saved orientation or default to left
        let savedOrientation = userDefaults.string(forKey: DefaultsKeys.assistantDefaultOrientation)
        self.assistantDefaultOrientation = AssistantOrientation(rawValue: savedOrientation ?? "left") ?? .left
    }
    
    // MARK: - Public Methods
    func resetToDefaults() {
        assistantDefaultOrientation = .left
    }
}
