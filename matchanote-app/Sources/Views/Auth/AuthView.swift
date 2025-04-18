import SwiftUI
import matchanote_app

struct AuthView: View {
  @StateObject private var authManager = LocalAuthManager.shared

  var body: some View {
    Group {
      if authManager.isLoggedIn {
        DocumentsView()
      } else if authManager.isFirstLaunch {
        OnboardingView()
          .environmentObject(authManager)
      } else {
        SignInView()
          .environmentObject(authManager)
      }
    }
  }
}

#Preview {
  AuthView()
}
