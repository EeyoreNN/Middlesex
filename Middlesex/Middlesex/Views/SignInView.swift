//
//  SignInView.swift
//  Middlesex
//
//  Sign in with Apple authentication screen
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [MiddlesexTheme.primaryRed, MiddlesexTheme.primaryRed.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // School branding
                VStack(spacing: 16) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("Middlesex")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your School, Your Schedule")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // Sign in section
                VStack(spacing: 20) {
                    Text("Get Started")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    // Sign in with Apple button
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleSignInWithApple(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .padding(.horizontal, 40)
                    }

                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }

                Spacer()

                // Privacy note
                Text("Your data is stored securely and never shared")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
    }

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        isAuthenticating = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Store user identifier
                preferences.userIdentifier = appleIDCredential.user

                // Extract full name
                if let fullName = appleIDCredential.fullName {
                    let firstName = fullName.givenName ?? ""
                    let lastName = fullName.familyName ?? ""
                    let displayName = [firstName, lastName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")

                    if !displayName.isEmpty {
                        preferences.userName = displayName
                    }
                }

                // Extract email
                if let email = appleIDCredential.email {
                    preferences.userEmail = email
                }

                // Mark as signed in
                preferences.isSignedIn = true

                print("✅ Sign in successful: \(preferences.userIdentifier)")
                print("📧 Email: \(preferences.userEmail)")
                print("👤 Name: \(preferences.userName)")
            }

        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("❌ Sign in error: \(error)")
        }

        isAuthenticating = false
    }
}

#Preview {
    SignInView()
}
