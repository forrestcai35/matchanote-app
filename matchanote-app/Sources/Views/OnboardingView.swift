//
//  ContentView.swift
//  MatchaNotes
//
//  Created by Forrest Cai on 4/1/25.
//

import SwiftUI
import matchanote_app

struct OnboardingView: View {
    @State private var showHomeView = false
    @ObservedObject private var tabManager = TabManager.shared

    var body: some View {
        ZStack {
            if showHomeView {
                DocumentsView()
            } else {
                VStack(spacing: 30) {
                    // Logo
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(.bottom, 20)

                    Text("Welcome to Matcha")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Your notes, powered with AI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 30)

                    // Apple Sign In
                    Button(action: {
                        // Handle Apple sign in
                        showHomeView = true
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                            Text("Sign in with Apple")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    // Google Sign In
                    Button(action: {
                        // Handle Google sign in
                        showHomeView = true
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Sign in with Google")
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
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
                .padding(.vertical)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
