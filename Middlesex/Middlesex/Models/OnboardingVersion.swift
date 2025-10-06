//
//  OnboardingVersion.swift
//  Middlesex
//
//  Tracks onboarding version to detect when updates need new information
//

import Foundation

struct OnboardingVersion {
    static let current = 2 // Increment this when adding new questions

    // Version history:
    // v1: Initial onboarding (name, grade, schedule)
    // v2: Added extracurricular (chorus, senate, extended blocks)

    static func missingQuestions(currentVersion: Int) -> [MissingQuestion] {
        var missing: [MissingQuestion] = []

        if currentVersion < 2 {
            missing.append(.extracurricular)
        }

        // Add more as we add features:
        // if currentVersion < 3 {
        //     missing.append(.newFeature)
        // }

        return missing
    }
}

enum MissingQuestion {
    case extracurricular
    // Add more cases as needed

    var title: String {
        switch self {
        case .extracurricular:
            return "Extracurricular Activities"
        }
    }

    var description: String {
        switch self {
        case .extracurricular:
            return "We need to know about your chorus participation, senate involvement, and extended blocks."
        }
    }
}

// Extension to UserPreferences for version tracking
extension UserPreferences {
    private var onboardingVersionKey: String { "onboardingVersion" }

    var onboardingVersion: Int {
        get {
            UserDefaults.standard.integer(forKey: onboardingVersionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: onboardingVersionKey)
        }
    }

    var needsUpdate: Bool {
        hasCompletedOnboarding && onboardingVersion < OnboardingVersion.current
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingVersion = OnboardingVersion.current
    }
}
