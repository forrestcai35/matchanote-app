import Foundation
import Supabase

/// Centralized authentication service for sign in, sign up, sign out, and account deletion
actor AuthService {
    static let shared = AuthService()

    private init() {}

    // MARK: - Sign In

    func signInWithEmail(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
        await MainActor.run { LocalAuthManager.shared.setLoggedIn() }
    }

    func signInWithGoogle() async throws {
        _ = try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "matchanote://authcallback")!,
            queryParams: [(name: "prompt", value: "select_account")]
        )
        await MainActor.run { LocalAuthManager.shared.setLoggedIn() }
    }

    func signInWithApple() async throws {
        _ = try await supabase.auth.signInWithOAuth(
            provider: .apple,
            redirectTo: URL(string: "matchanote://authcallback")!
        )
        await MainActor.run { LocalAuthManager.shared.setLoggedIn() }
    }

    // MARK: - Sign Up

    func signUpWithEmail(email: String, password: String) async throws {
        try await supabase.auth.signUp(
            email: email,
            password: password,
            redirectTo: URL(string: "matchanote://authcallback")!
        )
        await MainActor.run { LocalAuthManager.shared.setLoggedIn() }
    }

    // OAuth sign up uses the same methods as sign in
    func signUpWithGoogle() async throws {
        try await signInWithGoogle()
    }

    func signUpWithApple() async throws {
        try await signInWithApple()
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await auth.signOut()
        } catch {
            print("Supabase signOut error: \(error)")
        }
        await MainActor.run { LocalAuthManager.shared.logout() }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        let session = try await supabase.auth.session
        let accessToken = session.accessToken

        guard let url = URL(string: "https://matchanote.app/api/delete-account") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw AuthError.invalidResponse
        }

        print("📡 Delete account response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            print("✅ Account deletion successful")
            await signOut()
        } else if httpResponse.statusCode == 404 {
            print("❌ Delete account endpoint not found (404)")
            throw AuthError.serverError("Account deletion is currently unavailable. Please contact support.")
        } else {
            // Try to parse error message from response
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Server response: \(responseString)")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["error"] as? String {
                print("❌ Server error: \(errorMessage)")
                throw AuthError.serverError(errorMessage)
            } else {
                print("❌ Account deletion failed with status: \(httpResponse.statusCode)")
                throw AuthError.deletionFailed("Server returned status \(httpResponse.statusCode)")
            }
        }
    }

    // MARK: - Helpers

    func getCurrentEmail() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.email
        } catch {
            return nil
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case deletionFailed(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .deletionFailed(let message): return message
        case .serverError(let message): return message
        }
    }
}
