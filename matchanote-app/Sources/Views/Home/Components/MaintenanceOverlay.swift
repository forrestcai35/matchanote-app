//
//  MaintenanceOverlay.swift
//  matchanote-app
//
//  Full-screen overlay shown during maintenance mode
//

import SwiftUI

struct MaintenanceOverlay: View {
    let maintenance: MaintenanceConfig
    @Environment(\.colorScheme) var colorScheme
    @Binding var isDismissed: Bool
    @State private var showWarningAlert = false

    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark
                ? Color.matchabackground_dark
                : Color.matchabackground_light)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Mascot
                MatchaMascot(emotion: .sad, size: .extraLarge)

                // Content
                VStack(spacing: 16) {
                    Text(maintenance.title)
                        .font(.jost(.largeTitle()))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(maintenance.message)
                        .font(.jost(.body()))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Continue button
                Button(action: {
                    showWarningAlert = true
                }) {
                    Text("Continue Anyway")
                        .font(.jost(.body()))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange)
                        )
                }
                .padding(.horizontal, 32)

                // Footer
                Text("Thank you for your patience")
                    .font(.jost(.caption()))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
            }
            .padding()
        }
        .alert("Warning", isPresented: $showWarningAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                isDismissed = true
            }
        } message: {
            Text("The app is currently under maintenance. If you continue, key features may not work properly and your notes might not be saved. You risk losing data during this time.")
        }
    }
}
