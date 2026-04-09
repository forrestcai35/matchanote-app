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

  // Switch to signup view
  func showSignUpView() {
    showSignIn = false
  }
  
  // MARK: - Session Validation
  
  /// Validates the current session with Supabase and ensures account still exists
  func validateSession() async {
    do {
      let session = try await auth.session
      let userId = session.user.id.uuidString

      // Ensure the corresponding account record still exists in our DB
      do {
        let response = try await supabase
          .from("user_subscription")
          .select("*")
          .eq("user_id", value: userId)
          .limit(1)
          .execute()

        let rows = (try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]]) ?? []
        if rows.isEmpty {
          print("❌ No user record found for current session (userId=\(userId)). Forcing sign out.")
          await MainActor.run {
            logout()
          }
          return
        }

        print("✅ Session and account validation successful")
      } catch {
        print("❌ Account lookup failed: \(error). Forcing sign out for safety.")
           print("⚠️ Account lookup failed: \(error). Keeping session and retrying later.")
          return
       
      }
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
