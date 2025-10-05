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
    @StateObject private var documentHandler = DocumentHandler.shared

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(authManager)
                .environmentObject(storageManager)
                .environmentObject(preferencesManager)
                .environmentObject(documentHandler)
                .preferredColorScheme(colorSchemeForTheme(preferencesManager.theme))
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
    }
    
    private func handleOpenURL(_ url: URL) {
        print("App: Received URL: \(url)")
        
        // Check if it's a document URL
        if url.startAccessingSecurityScopedResource() {
            documentHandler.handleDocumentURL(url)
            url.stopAccessingSecurityScopedResource()
        } else {
            // Handle other URL schemes (like auth callbacks)
            if url.scheme == "matchanote" {
                // Handle auth callback or other app-specific URLs
                print("App: Handling app-specific URL: \(url)")
            }
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
