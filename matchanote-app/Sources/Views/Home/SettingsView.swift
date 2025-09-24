import SwiftUI

// Settings popover view
struct SettingsPopover: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var showingPreferences = false
  @State private var showingTrash = false

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("Settings")
        .font(.headline)
        .foregroundColor(
          colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
        .padding(.bottom, 5)

      Divider()

      Button(action: {
        if let url = URL(string: "https://matchanote.app/app/settings") {
          UIApplication.shared.open(url)
        }
      }) {
        Label("Account", systemImage: "person.circle")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
      .buttonStyle(PlainButtonStyle())

      Button(action: {
        showingPreferences = true
      }) {
        Label("Preferences", systemImage: "paintpalette")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
      .buttonStyle(PlainButtonStyle())

      Button(action: {
        showingTrash = true
      }) {
        Label("Trash", systemImage: "trash")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .foregroundColor(colorScheme == .dark ? Color.matchadark_dark : Color.matchadark_light)
      .buttonStyle(PlainButtonStyle())

      Divider()

      Button(action: {
        LocalAuthManager.shared.logout()
      }) {
        Label("Sign Out", systemImage: "arrow.right.square")
          .foregroundColor(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding()
    .frame(width: 200)
    .sheet(isPresented: $showingPreferences) {
      PreferencesView()
    }
    .sheet(isPresented: $showingTrash) {
      TrashView()
    }
  }
}
