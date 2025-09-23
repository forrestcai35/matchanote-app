import SwiftUI

// Settings popover view
struct SettingsPopover: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var showingPreferences = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Settings")
        .font(.headline)
        .padding(.bottom, 5)

      Divider()

      // Subscription status removed

      Button(action: {
        if let url = URL(string: "https://matchanote.app/app/settings") {
          UIApplication.shared.open(url)
        }
      }) {
        Label("Account", systemImage: "person.circle")
      }
      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)

      Button(action: {
        showingPreferences = true
      }) {
        Label("Preferences", systemImage: "paintpalette")
      }
      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)


      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
      Button(action: {
        // Trashcan
      }) {
        Label("Trash", systemImage: "trash")
      }
      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
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
    .sheet(isPresented: $showingPreferences) {
      PreferencesView()
    }
  }
}
