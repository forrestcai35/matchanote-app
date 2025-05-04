import AuthenticationServices
import Foundation
import Supabase
import SwiftUI

struct SignInView: View {
  @EnvironmentObject private var authManager: LocalAuthManager
  @State private var isLoading = false
  @State private var errorMessage: String? = nil
  @State private var email = ""
  @State private var password = ""

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let isLandscape = geometry.size.width > geometry.size.height
        let spacing: CGFloat = isLandscape ? 15 : 30

        ScrollView {
          VStack(spacing: spacing) {

            Image("Logo")
              .resizable()
              .scaledToFit()
              .frame(width: isLandscape ? 80 : 100, height: isLandscape ? 80 : 100)
              .padding(.bottom, isLandscape ? 5 : 10)

              .padding(50)

            Text("Welcome Back")
              .font(.title)
              .fontWeight(.bold)

            Text("Sign in to continue")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .padding(.bottom, isLandscape ? 10 : 20)

            // Email field
            VStack(alignment: .leading) {
              Text("Email")
                .font(.caption)
                .foregroundColor(.secondary)
              TextField("you@example.com", text: $email)

                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: min(geometry.size.width * 0.8, 450))

            // Password field
            VStack(alignment: .leading) {
              Text("Password")
                .font(.caption)
                .foregroundColor(.secondary)
              SecureField("Your password", text: $password)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: min(geometry.size.width * 0.8, 450))

            // Sign In button
            Button(action: {
              Task {
                await signInWithEmail()
              }
            }) {
              if isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
              } else {
                Text("Sign In")
                  .fontWeight(.semibold)
              }
            }
            .frame(width: min(geometry.size.width * 0.6, 450))
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            // Error message
            if let errorMessage = errorMessage {
              Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .padding(.top, 5)
            }

            HStack {
              Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
              Text("OR").foregroundColor(.secondary).font(.caption)
              Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
            }
            .frame(width: min(geometry.size.width * 0.8, 450))

            HStack(spacing: isLandscape ? 15 : 20) {

              Button(action: {
                Task {
                  await signInWithGoogle()
                }
              }) {
                Image(systemName: "g.circle.fill")
                  .font(.title2)
                  .frame(width: isLandscape ? 50 : 60, height: isLandscape ? 50 : 60)
                  .background(Color.white)
                  .foregroundColor(.black)
                  .clipShape(Circle())
                  .overlay(
                    Circle()
                      .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                  )
              }
              .disabled(isLoading)
            }

            HStack {
              Text("Don't have an account?")
                .foregroundColor(.secondary)

              Button("Sign Up") {
                authManager.showOnboardingView()
              }
              .foregroundColor(.green)
              .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.top, isLandscape ? 5 : 10)

            Spacer()
          }
          .padding()
          .frame(minHeight: geometry.size.height)
          .frame(width: geometry.size.width)

        }
      }
      .navigationBarBackButtonHidden(true)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          EmptyView()
        }
      }
    }
  }

  // MARK: - Authentication Methods

  private func signInWithEmail() async {
    isLoading = true
    errorMessage = nil

    if email.isEmpty || password.isEmpty {
      errorMessage = "Please enter an email and password"
      isLoading = false
      return
    }

    do {
      try await supabase.auth.signIn(
        email: email,
        password: password
      )
      self.isLoading = false
      self.authManager.setLoggedIn()
    } catch {
      handleAuthError(error)
    }
  }

  private func signInWithGoogle() async {
    isLoading = true
    errorMessage = nil

    do {
      let _ = try await supabase.auth.signInWithOAuth(
        provider: .google
      ) { (session: ASWebAuthenticationSession) in
      }
      self.isLoading = false
      self.authManager.setLoggedIn()
    } catch {
      handleAuthError(error)
    }
  }

  // Handle authentication errors
  private func handleAuthError(_ error: Error) {
    isLoading = false
    errorMessage = "Authentication failed: \(error.localizedDescription)"
    print("Auth error: \(error)")
  }
}
