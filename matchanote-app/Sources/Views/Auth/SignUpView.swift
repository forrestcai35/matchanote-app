
import Foundation
import Supabase
import SwiftUI

struct SignUpView: View {
  @EnvironmentObject private var authManager: LocalAuthManager
  @State private var errorMessage: String? = nil
  @State private var showError = false
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var showEmailSignUp = false
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
            Spacer(minLength: geometry.size.height * 0.08)

            // Logo and title section
            VStack(spacing: 24) {
              Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), radius: 8)

              VStack(spacing: 12) {
                Text("Welcome to Matcha")
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

                VStack(spacing: 6) {
                  Text("Your notes, powered with AI")
                    .font(.jost(.headline()))
                    .foregroundColor(.secondary)

                  Text("Choose your preferred sign-up method")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
              }
            }

            .padding(.bottom, 32)

            // Auth options section
            VStack(spacing: 16) {
              if showEmailSignUp {
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

                    SecureField("Create a password", text: $password)
                      .textContentType(.newPassword)
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
                    Text("Confirm Password")
                      .font(.jost(.callout()))
                      .foregroundColor(.secondary)

                    SecureField("Confirm your password", text: $confirmPassword)
                      .textContentType(.newPassword)
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
                          .stroke(
                            password != confirmPassword && !confirmPassword.isEmpty
                            ? Color.red.opacity(0.5)
                            : Color.gray.opacity(0.2),
                            lineWidth: 1
                          )
                      )
                  }

                  if !confirmPassword.isEmpty && password != confirmPassword {
                    Text("Passwords don't match")
                      .font(.jost(.caption()))
                      .foregroundColor(.red)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }

                  // Sign Up Button
                  Button(action: {
                    Task {
                      await signUpWithEmail()
                    }
                  }) {
                    Text("Create Account")
                      .font(.jost(.subheadline()))
                      .foregroundColor(.white)
                      .frame(maxWidth: .infinity)
                      .frame(height: 56)
                      .background(
                        isFormValid
                        ? (colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light)
                        : Color.gray
                      )
                      .cornerRadius(12)
                      .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                  }
                  .disabled(!isFormValid)

                  // Back to OAuth button
                  Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                      showEmailSignUp = false
                      email = ""
                      password = ""
                      confirmPassword = ""
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
                  // Apple Sign Up
                  Button(action: {
                    Task {
                      await oauthWithApple()
                    }
                  }) {
                    HStack(spacing: 12) {
                      Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .medium))

                      Text("Sign up with Apple")
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

                  // Google Sign Up
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

                      Text("Sign up with Google")
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

                  // Email Sign Up Button DISABLED for NOW
              //     Button(action: {
              //       withAnimation(.easeInOut(duration: 0.3)) {
              //         showEmailSignUp = true
              //       }
              //     }) {
              //       HStack(spacing: 12) {
              //         Image(systemName: "envelope")
              //           .font(.system(size: 18, weight: .medium))
              //           .foregroundColor(.secondary)

              //         Text("Sign up with Email")
              //           .font(.jost(.subheadline()))
              //           .foregroundColor(.secondary)
              //       }
              //       .frame(maxWidth: min(geometry.size.width * 0.8, 400))
              //       .frame(height: 56)
              //       .background(Color.clear)
              //       .cornerRadius(12)
              //       .overlay(
              //         RoundedRectangle(cornerRadius: 12)
              //           .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
              //       )
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


            // Terms and Privacy (optional)
            VStack(spacing: 4) {
                Text("By signing up, you agree to our")
                    .font(.jost(.caption()))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Link("Terms of Service", destination: URL(string: "https://matchanote.app/terms-of-service")!)
                    Text("and")
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                    Link("Privacy Policy", destination: URL(string: "https://matchanote.app/privacy-policy")!)
                }
                .font(.jost(.caption()))
                .foregroundColor(colorScheme == .dark ? .matchalight_dark : .matchalight_light)
            }
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)
              .padding(.bottom, 16)



            // Sign in prompt
            HStack(spacing: 4) {
              Text("Already have an account?")
                .font(.jost(.subheadline()))
                .foregroundColor(.secondary)

              Button("Sign In") {
                authManager.showSignInView()
              }
              .font(.jost(.subheadline()))
              .foregroundColor(colorScheme == .dark ? .matchalight_dark : .matchalight_light)
            }

            Spacer(minLength: 32)
          }
          .padding(.horizontal, 24)
        }
      }
      .navigationBarHidden(true)
    }
  }

  // MARK: - Computed Properties

  private var isFormValid: Bool {
    !email.isEmpty &&
    !password.isEmpty &&
    !confirmPassword.isEmpty &&
    password == confirmPassword &&
    password.count >= 6
  }

  // MARK: - Authentication Methods

  private func signUpWithEmail() async {
    await MainActor.run { 
      showError = false
      errorMessage = nil
    }
    guard isFormValid else {
      await MainActor.run {
        if password != confirmPassword {
          errorMessage = "Passwords don't match."
        } else if password.count < 6 {
          errorMessage = "Password must be at least 6 characters."
        } else {
          errorMessage = "Please fill in all fields."
        }
        showErrorWithFade()
      }
      return
    }
    do {
      try await AuthService.shared.signUpWithEmail(email: email, password: password)
    } catch {
      await MainActor.run { 
        errorMessage = "Failed to create account. Please try again."
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
      try await AuthService.shared.signUpWithGoogle()
    } catch {
      await MainActor.run { 
        errorMessage = "Sign up with Google failed. Please try again."
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
      try await AuthService.shared.signUpWithApple()
    } catch {
      await MainActor.run { 
        errorMessage = "Sign up with Apple failed. Please try again."
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
