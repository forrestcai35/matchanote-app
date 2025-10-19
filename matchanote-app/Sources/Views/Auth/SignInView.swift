import Foundation
import Supabase
import SwiftUI

struct SignInView: View {
  @EnvironmentObject private var authManager: LocalAuthManager
  @State private var isLoading = false
  @State private var errorMessage: String? = nil
  @State private var email = ""
  @State private var password = ""
  @State private var showEmailSignIn = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ZStack {
          // Background gradient
          LinearGradient(
            gradient: Gradient(colors: [
              colorScheme == .dark ? Color.matchabackground_dark : Color.matchabackground_light,
              colorScheme == .dark ? Color.matchabackground_dark.opacity(0.8) : Color.matchabackground_light.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .ignoresSafeArea()

          VStack(spacing: 0) {
            Spacer(minLength: geometry.size.height * 0.1)

            // Logo and title section
            VStack(spacing: 24) {
              Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), radius: 8)

              VStack(spacing: 8) {
                Text("Welcome Back")
                  .font(.system(size: 40, weight: .bold, design: .rounded))
                  .foregroundStyle(
                    LinearGradient(
                      gradient: Gradient(colors: [
                        colorScheme == .dark ? .matcha_logo_color : .matcha_logo_color,
                        colorScheme == .dark ? .matchadark_dark : .matchadark_light
                      ]),
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
                  .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), radius: 2, x: 0, y: 1)

                Text("Choose your preferred sign-in method")
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
              }
            }

            Spacer(minLength: geometry.size.height * 0.08)

            // Auth options section
            VStack(spacing: 16) {
              if showEmailSignIn {
                // Email/Password Form
                VStack(spacing: 16) {
                  VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.secondary)

                    TextField("Enter your email", text: $email)
                      .textContentType(.emailAddress)
                      .autocapitalization(.none)
                      .autocorrectionDisabled()
                      .font(.system(size: 16))
                      .padding(.horizontal, 16)
                      .padding(.vertical, 16)
                      .background(
                        colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.05)
                      )
                      .cornerRadius(12)
                      .overlay(
                        RoundedRectangle(cornerRadius: 12)
                          .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                      )
                  }

                  VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.secondary)

                    SecureField("Enter your password", text: $password)
                      .textContentType(.password)
                      .font(.system(size: 16))
                      .padding(.horizontal, 16)
                      .padding(.vertical, 16)
                      .background(
                        colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.05)
                      )
                      .cornerRadius(12)
                      .overlay(
                        RoundedRectangle(cornerRadius: 12)
                          .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                      )
                  }

                  // Sign In Button
                  Button(action: {
                    if !isLoading {
                      Task {
                        await signInWithEmail()
                      }
                    }
                  }) {
                    HStack(spacing: 12) {
                      if isLoading {
                        ProgressView()
                          .progressViewStyle(CircularProgressViewStyle(tint: .white))
                          .scaleEffect(0.8)
                      }

                      Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                      email.isEmpty || password.isEmpty
                      ? Color.gray
                      : (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                    )
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  }
                  .disabled(isLoading || email.isEmpty || password.isEmpty)

                  // Back to OAuth button
                  Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                      showEmailSignIn = false
                      email = ""
                      password = ""
                      errorMessage = nil
                    }
                  }) {
                    Text("Use OAuth instead")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.secondary)
                  }
                }
                .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                .transition(.opacity)

              } else {
                // OAuth buttons
                VStack(spacing: 16) {
                  // Apple Sign In
                  Button(action: {
                    if !isLoading {
                      Task {
                        await oauthWithApple()
                      }
                    }
                  }) {
                    HStack(spacing: 12) {
                      if isLoading {
                        ProgressView()
                          .progressViewStyle(CircularProgressViewStyle(tint: .black))
                          .scaleEffect(0.8)
                      } else {
                        Image(systemName: "apple.logo")
                          .font(.system(size: 20, weight: .medium))
                      }

                      Text("Continue with Apple")
                        .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                      RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  }
                  .disabled(isLoading)

                  // Google Sign In
                  Button(action: {
                    if !isLoading {
                      Task {
                        await oauthWithGoogle()
                      }
                    }
                  }) {
                    HStack(spacing: 12) {
                        if isLoading {
                          ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                        } else {
                            Image("google_logo")
                              .resizable()
                              .scaledToFit()
                              .frame(width: 20, height: 20)

                        }

                      Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    }
                    .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                      RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  }
                  .disabled(isLoading)

                  // OR divider
                  HStack {
                    Rectangle()
                      .fill(Color.secondary.opacity(0.3))
                      .frame(height: 1)

                    Text("OR")
                      .font(.system(size: 14, weight: .medium))
                      .foregroundColor(.secondary)
                      .padding(.horizontal, 16)

                    Rectangle()
                      .fill(Color.secondary.opacity(0.3))
                      .frame(height: 1)
                  }
                  .padding(.vertical, 8)

                  // Email Sign In Button
                  Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                      showEmailSignIn = true
                    }
                  }) {
                    HStack(spacing: 12) {
                      Image(systemName: "envelope")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)

                      Text("Sign in with Email")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                    .frame(height: 56)
                    .background(Color.clear)
                    .cornerRadius(12)
                    .overlay(
                      RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                  }
                  .disabled(isLoading)
                }
                .transition(.opacity)
              }
            }

            // Error message
            if let errorMessage = errorMessage {
              Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }

            Spacer(minLength: geometry.size.height * 0.08)

            // Sign up prompt
            HStack(spacing: 4) {
              Text("New to Matcha?")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

              Button("Create Account") {
                authManager.showOnboardingView()
              }
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(colorScheme == .dark ? .matchalight_dark : .matchalight_light)
            }

            Spacer(minLength: 32)
          }
          .padding(.horizontal, 24)
        }
      }
      .navigationBarBackButtonHidden(true)
    }
  }

  // MARK: - Authentication Methods

  private func signInWithEmail() async {
    await MainActor.run {
      isLoading = true
      errorMessage = nil
    }

    guard !email.isEmpty && !password.isEmpty else {
      await MainActor.run {
        isLoading = false
        errorMessage = "Please enter both email and password."
      }
      return
    }

    do {
      try await supabase.auth.signIn(
        email: email,
        password: password
      )
      await MainActor.run {
        isLoading = false
        authManager.setLoggedIn()
      }
    } catch {
      await MainActor.run {
        isLoading = false
        errorMessage = "Invalid email or password. Please try again."
      }
    }
  }

  private func oauthWithGoogle() async {
    await MainActor.run {
      isLoading = true
      errorMessage = nil
    }

    do {
      let _ = try await supabase.auth.signInWithOAuth(
        provider: .google,
        redirectTo: URL(string: "matchanote://authcallback")!
      )
      await MainActor.run {
        isLoading = false
        authManager.setLoggedIn()
      }
    } catch {
      await MainActor.run {
        isLoading = false
        errorMessage = "Sign in with Google failed. Please try again."
      }
    }
  }

  private func oauthWithApple() async {
    await MainActor.run {
      isLoading = true
      errorMessage = nil
    }

    do {
      let _ = try await supabase.auth.signInWithOAuth(
        provider: .apple,
        redirectTo: URL(string: "matchanote://authcallback")!
      ) 
      await MainActor.run {
        isLoading = false
        authManager.setLoggedIn()
      }
    } catch {
      await MainActor.run {
        isLoading = false
        errorMessage = "Sign in with Apple failed. Please try again."
      }
    }
  }
}
