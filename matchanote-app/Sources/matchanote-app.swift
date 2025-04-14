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
    @StateObject private var authManager = LocalAuthManager.shared

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environmentObject(authManager)
        }
    }
}
