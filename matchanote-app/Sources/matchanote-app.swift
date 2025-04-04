//
//  matchanote_appApp.swift
//  matchanote-app
//
//  Created by Forrest Cai on 4/4/25.
//

import SwiftUI
import matchanote_app

@main
struct matchanote_App: App {
    // Create a shared TabManager instance
    @StateObject private var tabManager = TabManager()

    var body: some Scene {
        WindowGroup {
            DocumentsView()
                .environmentObject(tabManager)
        }
    }
}
