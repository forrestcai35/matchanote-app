//
//  ContentView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import AuthenticationServices
import Foundation
import SwiftUI
import matchanote_app

struct OnboardingView: View {
  @EnvironmentObject private var authManager: LocalAuthManager
  @State private var isLoading = false
  @State private var errorMessage: String? = nil
  @State private var email = ""
  @State private var password = ""
  @State private var confirmPassword = ""
  @State private var showSignInView = false

  var body: some View {
    NavigationView {
      GeometryReader { geometry in
        let isLandscape = geometry.size.width > geometry.size.height
        let spacing: CGFloat = isLandscape ? 10 : 30

        ScrollView {
          VStack(spacing: spacing) {
            // Logo
            Image("Logo")
              .resizable()
              .scaledToFit()
              .frame(width: isLandscape ? 80 : 120, height: isLandscape ? 80 : 120)
              .padding(.bottom, isLandscape ? 5 : 20)

            Text("Welcome to Matcha")
              .font(.title)
              .fontWeight(.bold)

            Text("Your notes, powered with AI")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .padding(.bottom, isLandscape ? 5 : 20)

            Text("Create your account")
              .font(.headline)
              .padding(.bottom, isLandscape ? 5 : 10)

            // Email field
            VStack(alignment: .leading) {
              Text("Email")
                .font(.caption)
                .foregroundColor(.secondary)
              TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
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
              SecureField("Create a password", text: $password)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: min(geometry.size.width * 0.8, 450))

            // Confirm Password field
            VStack(alignment: .leading) {
              Text("Confirm Password")
                .font(.caption)
                .foregroundColor(.secondary)
              SecureField("Confirm your password", text: $confirmPassword)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: min(geometry.size.width * 0.8, 450))

            // Sign Up Button
            Button(action: {
              signUpWithEmail()
            }) {
              if isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
              } else {
                Text("Sign Up")
                  .fontWeight(.semibold)
              }
            }
            .frame(width: min(geometry.size.width * 0.8, 450))
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isLoading || email.isEmpty || password.isEmpty || password != confirmPassword)

            // Or continue with divider
            HStack {
              Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
              Text("OR").foregroundColor(.secondary).font(.caption)
              Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
            }
            .frame(width: min(geometry.size.width * 0.8, 450))

            // Apple Sign In Button
            // Button(action: {
            //   signInWithApple()
            // }) {
            //   HStack {
            //     Image(systemName: "apple.logo")
            //       .font(.title3)
            //     Text("Continue with Apple")
            //       .fontWeight(.semibold)
            //   }
            //   .frame(maxWidth: .infinity)
            //   .padding()
            //   .background(Color.black)
            //   .foregroundColor(.white)
            //   .cornerRadius(10)
            // }
            // .frame(width: min(geometry.size.width * 0.7, 450))

            // Google Sign In Button
            Button(action: {
              signInWithGoogle()
            }) {
              HStack {
                Image(systemName: "g.circle.fill")
                  .font(.title3)
                Text("Continue with Google")
                  .fontWeight(.semibold)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.white)
              .foregroundColor(.black)
              .cornerRadius(10)
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .stroke(Color.gray.opacity(0.3), lineWidth: 1)
              )
            }
            .frame(width: min(geometry.size.width * 0.7, 450))

            // Error message
            if let errorMessage = errorMessage {
              Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .padding(.top, isLandscape ? 5 : 10)
            }

            HStack {
              Text("Already have an account?")
                .foregroundColor(.secondary)

              Button("Sign In") {
                showSignInView = true
              }
              .foregroundColor(.green)
              .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.top, isLandscape ? 5 : 20)

            Spacer()
          }
          .padding()
          .padding(.vertical)
          .frame(minHeight: geometry.size.height)
          .frame(width: geometry.size.width)
          .navigationBarHidden(true)
          .background(
            NavigationLink(
              "",
              destination: SignInView()
                .environmentObject(authManager),
              isActive: $showSignInView
            )
            .opacity(0)
          )
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }

  // MARK: - Authentication Methods
  // private func signInWithApple() {
  //   isLoading = true
  //   errorMessage = nil

  //   DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
  //     self.isLoading = false
  //     self.authManager.setLoggedIn()
  //   }
  // }

  private func signInWithGoogle() {
    isLoading = true
    errorMessage = nil

    // Simulate network request
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      self.isLoading = false
      self.authManager.setLoggedIn()
    }
  }

  // Handle authentication errors
  private func handleAuthError(_ error: Error) {
    isLoading = false
    errorMessage = "Authentication failed: \(error.localizedDescription)"
    print("Auth error: \(error)")
  }

  private func signUpWithEmail() {
    isLoading = true
    errorMessage = nil

    // Validate password
    if password != confirmPassword {
      errorMessage = "Passwords do not match"
      isLoading = false
      return
    }

    // Simulate network request
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {

      // try await supabase.auth.signUp(email: email, password: password)
      self.isLoading = false
      self.authManager.setLoggedIn()
    }
  }
}

#Preview {
  OnboardingView()
    .environmentObject(LocalAuthManager.shared)
}
