//
//  ContentView.swift
//  Middlesex
//
//  Created by Nick Noon on 10/6/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var preferences = UserPreferences.shared

    var body: some View {
        Group {
            if !preferences.isSignedIn {
                // Step 1: Sign in with Apple
                SignInView()
            } else if !preferences.hasCompletedOnboarding {
                // Step 2: First time user - full onboarding
                OnboardingView()
            } else if preferences.needsUpdate {
                // Step 3: Existing user needs to answer new questions
                UpdateNeededView(
                    missingQuestions: OnboardingVersion.missingQuestions(
                        currentVersion: preferences.onboardingVersion
                    )
                )
            } else {
                // Step 4: All set - show main app
                MainTabView()
            }
        }
    }
}

#Preview {
    ContentView()
}
