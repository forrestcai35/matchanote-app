import Foundation
import Supabase
import SwiftUI

struct SignInView: View {
  @EnvironmentObject private var authManager: LocalAuthManager
  @State private var errorMessage: String? = nil
  @State private var showError = false
  @State private var email = ""
  @State private var password = ""
  @State private var showEmailSignIn = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ZStack {
          // Background gradient (top-left to bottom-right)
          LinearGradient(
            gradient: Gradient(colors: [
              Color(red: 141.0/255.0, green: 198.0/255.0, blue: 63.0/255.0, opacity: 0.1),  // #8DC63F @ 10%
              Color(red: 244.0/255.0, green: 224.0/255.0, blue: 77.0/255.0, opacity: 0.1)   // #F4E04D @ 10%
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
                  .font(.jost(.largeTitle(40)))
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
                  .font(.jost(.subheadline()))
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
              }
            }

            .padding(.bottom, 32)

            // Auth options section
            VStack(spacing: 16) {
              if showEmailSignIn {
                // Email/Password Form
                VStack(spacing: 16) {
                  VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                      .font(.jost(.callout()))
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
                      .font(.jost(.callout()))
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
                    Task {
                      await signInWithEmail()
                    }
                  }) {
                    Text("Sign In")
                      .font(.jost(.subheadline()))
                      .foregroundColor(.white)
                      .frame(maxWidth: .infinity)
                      .frame(height: 56)
                      .background(
                        email.isEmpty || password.isEmpty
                        ? Color.gray
                        : (colorScheme == .dark ? Color.matchalight_dark : Color.matcha_logo_color)
                      )
                      .cornerRadius(12)
                      .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  }
                  .disabled(email.isEmpty || password.isEmpty)

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
                      .font(.jost(.callout()))
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
                    Task {
                      await oauthWithApple()
                    }
                  }) {
                    HStack(spacing: 12) {
                      Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .medium))

                      Text("Continue with Apple")
                        .font(.jost(.subheadline()))
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

                  // Google Sign In
                  Button(action: {
                    Task {
                      await oauthWithGoogle()
                    }
                  }) {
                    HStack(spacing: 12) {
                      Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                      Text("Continue with Google")
                        .font(.jost(.subheadline()))
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
                  .padding(.bottom, 32)

                  // OR divider
                  // HStack {
                  //   Rectangle()
                  //     .fill(Color.secondary.opacity(0.3))
                  //     .frame(height: 1)

                  //   Text("OR")
                  //     .font(.jost(.callout()))
                  //     .foregroundColor(.secondary)
                  //     .padding(.horizontal, 16)

                  //   Rectangle()
                  //     .fill(Color.secondary.opacity(0.3))
                  //     .frame(height: 1)
                  // }
                  // .padding(.vertical, 8)

                  // Email Sign In Button
                  // Button(action: {
                  //   withAnimation(.easeInOut(duration: 0.3)) {
                  //     showEmailSignIn = true
                  //   }
                  // }) {
                  //   HStack(spacing: 12) {
                  //     Image(systemName: "envelope")
                  //       .font(.system(size: 18, weight: .medium))
                  //       .foregroundColor(.secondary)

                  //     Text("Sign in with Email")
                  //       .font(.jost(.subheadline()))
                  //       .foregroundColor(.secondary)
                  //   }
                  //   .frame(maxWidth: min(geometry.size.width * 0.8, 400))
                  //   .frame(height: 56)
                  //   .background(Color.clear)
                  //   .cornerRadius(12)
                  //   .overlay(
                  //     RoundedRectangle(cornerRadius: 12)
                  //       .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                  //   )
                  // }
                  // .disabled(isLoading)
                }
                .transition(.opacity)
              }
            }

            // Error message
            if let errorMessage = errorMessage, showError {
              Text(errorMessage)
                .font(.jost(.callout()))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

        

            // Sign up prompt
            HStack(spacing: 4) {
              Text("New to Matcha?")
                .font(.jost(.subheadline()))
                .foregroundColor(.secondary)

              Button("Create Account") {
                authManager.showSignUpView()
              }
              .font(.jost(.subheadline()))
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
      showError = false
      errorMessage = nil
    }
    guard !email.isEmpty && !password.isEmpty else {
      await MainActor.run { 
        errorMessage = "Please enter both email and password."
        showErrorWithFade()
      }
      return
    }
    do {
      try await AuthService.shared.signInWithEmail(email: email, password: password)
    } catch {
      await MainActor.run { 
        errorMessage = "Invalid email or password. Please try again."
        showErrorWithFade()
      }
    }
  }

  private func oauthWithGoogle() async {
    await MainActor.run { 
      showError = false
      errorMessage = nil
    }
    do {
      try await AuthService.shared.signInWithGoogle()
    } catch {
      await MainActor.run { 
        errorMessage = "Sign in with Google failed. Please try again."
        showErrorWithFade()
      }
    }
  }

  private func oauthWithApple() async {
    await MainActor.run { 
      showError = false
      errorMessage = nil
    }
    do {
      try await AuthService.shared.signInWithApple()
    } catch {
      await MainActor.run { 
        errorMessage = "Sign in with Apple failed. Please try again."
        showErrorWithFade()
      }
    }
  }

  private func showErrorWithFade() {
    withAnimation(.easeIn(duration: 0.3)) {
      showError = true
    }
    
    Task {
      try? await Task.sleep(nanoseconds: 4_000_000_000)
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.3)) {
          showError = false
        }
      }
      try? await Task.sleep(nanoseconds: 300_000_000)
      await MainActor.run {
        errorMessage = nil
      }
    }
  }
}
