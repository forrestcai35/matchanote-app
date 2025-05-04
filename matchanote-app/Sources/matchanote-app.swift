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
    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(authManager)
                .environmentObject(storageManager)
        }
    }
}
