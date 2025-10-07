//
//  UpdateNeededView.swift
//  Middlesex
//
//  Shows when app is updated and needs additional information
//

import SwiftUI

struct UpdateNeededView: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var showingQuestions = false

    let missingQuestions: [MissingQuestion]

    var body: some View {
        ZStack {
            MiddlesexTheme.redGradient
                .ignoresSafeArea()

            if !showingQuestions {
                VStack(spacing: 30) {
                    Spacer()

                    // Update icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 16) {
                        Text("We've Updated!")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)

                        Text("We need a few more details to improve your experience")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    // What's new
                    VStack(alignment: .leading, spacing: 20) {
                        Text("What's New:")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)

                        ForEach(Array(missingQuestions.enumerated()), id: \.offset) { index, question in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)

                                    Image(systemName: iconForQuestion(question))
                                        .foregroundColor(MiddlesexTheme.primaryRed)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(question.title)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text(question.description)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                    .padding(.vertical, 20)

                    Spacer()

                    Button {
                        showingQuestions = true
                    } label: {
                        Text("Let's Go!")
                            .font(.headline)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MiddlesexTheme.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                    }

                    Button {
                        // Skip for now (still mark as completed to avoid showing again)
                        preferences.onboardingVersion = OnboardingVersion.current
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }

                    Spacer()
                        .frame(height: 20)
                }
            } else {
                // Show the missing questions
                if missingQuestions.contains(.extracurricular) {
                    ExtracurricularQuestionsView(
                        selectedClasses: getCurrentClasses(),
                        onComplete: {
                            preferences.onboardingVersion = OnboardingVersion.current
                        }
                    )
                }
            }
        }
    }

    private func iconForQuestion(_ question: MissingQuestion) -> String {
        switch question {
        case .extracurricular:
            return "music.note.list"
        }
    }

    private func getCurrentClasses() -> [String: SchoolClass] {
        // Convert user's saved schedule back to SchoolClass format
        var classes: [String: SchoolClass] = [:]
        let blocks = ["A", "B", "C", "D", "E", "F", "G"]

        for (index, block) in blocks.enumerated() {
            if let userClass = preferences.getClass(for: index + 1, weekType: .red) {
                // Find matching SchoolClass from the list
                if let schoolClass = ClassList.availableClasses.first(where: { $0.name == userClass.className }) {
                    classes[block] = schoolClass
                }
            }
        }

        return classes
    }
}

#Preview {
    UpdateNeededView(missingQuestions: [.extracurricular])
}
