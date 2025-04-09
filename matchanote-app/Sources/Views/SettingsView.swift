import SwiftUI
import matchanote_app

// Settings popover view
struct SettingsPopover: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Settings")
        .font(.headline)
        .padding(.bottom, 5)

      Divider()

      Button(action: {
        // Account settings action
      }) {
        Label("Account", systemImage: "person.circle")
      }

      Button(action: {
        // Preferences action
      }) {
        Label("Preferences", systemImage: "slider.horizontal.3")
      }

      Button(action: {
        // Theme action
      }) {
        Label("Theme", systemImage: "paintpalette")
      }

      Button(action: {
        // About action
      }) {
        Label("About", systemImage: "info.circle")
      }

      Divider()

      Button(action: {
        LocalAuthManager.shared.logout()
      }) {
        Label("Sign Out", systemImage: "arrow.right.square")
          .foregroundColor(.red)
      }
    }
    .padding()
    .frame(width: 200)
  }
}
