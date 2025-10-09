import Foundation
import SwiftUI
import Supabase

class LocalAuthManager: ObservableObject {
  static let shared = LocalAuthManager()
  private let userDefaults = UserDefaults.standard
  private let hasLaunchedBeforeKey = "hasLaunchedBefore"
  private let isLoggedInKey = "isLoggedIn"

  @Published var isFirstLaunch: Bool
  @Published var isLoggedIn: Bool
  @Published var showSignIn: Bool = true

  private init() {
    isFirstLaunch = !userDefaults.bool(forKey: hasLaunchedBeforeKey)
    isLoggedIn = userDefaults.bool(forKey: isLoggedInKey)
    showSignIn = !isFirstLaunch

    // If this is the first launch, update the flag
    if isFirstLaunch {
      userDefaults.set(true, forKey: hasLaunchedBeforeKey)
    }
  }

  // Mark user as logged in
  func setLoggedIn() {
    isLoggedIn = true
    userDefaults.set(true, forKey: isLoggedInKey)
  }

  // Log user out
  func logout() {
    isLoggedIn = false
    userDefaults.set(false, forKey: isLoggedInKey)
  }


  // Switch to sign in view
  func showSignInView() {
    showSignIn = true
    isFirstLaunch = false
  }

  // Switch to onboarding view
  func showOnboardingView() {
    showSignIn = false
  }
  
  // MARK: - Session Validation
  
  /// Validates the current session with Supabase
  func validateSession() async {
    do {
      _ = try await auth.session
      // If we can get the session without error, it's valid
      // The session object itself indicates validity
      print("✅ Session validation successful")
    } catch {
      // Session is invalid or expired
      print("❌ Session validation failed: \(error)")
      await MainActor.run {
        logout()
      }
    }
  }
  
  /// Checks if the user is authenticated and session is valid
  func isAuthenticated() -> Bool {
    return isLoggedIn
  }
  
  /// Force logout and clear all session data
  func forceLogout() {
    logout()
    // Clear any additional session data if needed
    userDefaults.removeObject(forKey: "userSessionData")
  }
}
