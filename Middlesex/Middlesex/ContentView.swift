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
            if !preferences.hasCompletedOnboarding {
                // First time user - full onboarding
                OnboardingView()
            } else if preferences.needsUpdate {
                // Existing user needs to answer new questions
                UpdateNeededView(
                    missingQuestions: OnboardingVersion.missingQuestions(
                        currentVersion: preferences.onboardingVersion
                    )
                )
            } else {
                // All set - show main app
                MainTabView()
            }
        }
    }
}

#Preview {
    ContentView()
}
