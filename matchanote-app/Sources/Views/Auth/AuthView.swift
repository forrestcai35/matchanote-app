import SwiftUI

struct AuthView: View {
  @StateObject private var authManager = LocalAuthManager.shared

  var body: some View {
    Group {
      if authManager.isLoggedIn {
        HomeView()
      } else if !authManager.showSignIn {
        SignUpView()
          .environmentObject(authManager)
      } else {
        SignInView()
          .environmentObject(authManager)
      }
    }
  }
}
