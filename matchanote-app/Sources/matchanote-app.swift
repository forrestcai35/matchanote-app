//
//  matchanote_appApp.swift
//  matchanote-app
//
//  Created by Forrest Cai on 4/4/25.
//

import SwiftUI

@main
struct matchanote_App: App {
    @StateObject private var authManager = LocalAuthManager.shared
    @StateObject private var storageManager = StorageManager()
    @StateObject private var preferencesManager = PreferencesManager.shared

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(authManager)
                .environmentObject(storageManager)
                .environmentObject(preferencesManager)
                .preferredColorScheme(colorSchemeForTheme(preferencesManager.theme))
        }
    }

    private func colorSchemeForTheme(_ theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Uses system setting
        }
    }
}
