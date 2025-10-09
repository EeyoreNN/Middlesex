//
//  ExtracurricularQuestionsView.swift
//  Middlesex
//
//  Questions about chorus and senate
//

import SwiftUI

struct ExtracurricularQuestionsView: View {
    @StateObject private var preferences = UserPreferences.shared
    let selectedClasses: [String: SchoolClass]
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var isInSmallChorus = false
    @State private var isInChapelChorus = false
    @State private var senatePosition: ExtracurricularInfo.SenatePosition = .none

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            ProgressView(value: Double(currentStep), total: 3)
                .tint(MiddlesexTheme.primaryRed)
                .padding()
                .background(Color.clear)

            Group {
                if currentStep == 0 {
                    // Small Chorus question
                    ChorusQuestionView(
                        title: "Are you in Small Chorus?",
                        icon: "music.note.list",
                        isSelected: $isInSmallChorus,
                        onNext: { currentStep += 1 }
                    )
                } else if currentStep == 1 {
                    // Chapel Chorus question
                    ChorusQuestionView(
                        title: "Are you in Chapel Chorus?",
                        icon: "music.mic",
                        isSelected: $isInChapelChorus,
                        onNext: { currentStep += 1 }
                    )
                } else if currentStep == 2 {
                    // Senate question
                    SenateQuestionView(
                        selectedPosition: $senatePosition,
                        onNext: { saveAndComplete() }
                    )
                }
            }
        }
        .background(MiddlesexTheme.redGradient.ignoresSafeArea())
    }

    private func saveAndComplete() {
        // Save extracurricular info
        preferences.extracurricularInfo = ExtracurricularInfo(
            isInSmallChorus: isInSmallChorus,
            isInChapelChorus: isInChapelChorus,
            senatePosition: senatePosition
        )

        onComplete()
    }
}

// MARK: - Chorus Question View

struct ChorusQuestionView: View {
    let title: String
    let icon: String
    @Binding var isSelected: Bool
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text(title)
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    isSelected = true
                    onNext()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Yes, I'm in \(title.contains("Small") ? "Small" : "Chapel") Chorus")
                    }
                    .font(.headline)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MiddlesexTheme.cardBackground)
                    .cornerRadius(12)
                }

                Button {
                    isSelected = false
                    onNext()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("No")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

// MARK: - Senate Question View

struct SenateQuestionView: View {
    @Binding var selectedPosition: ExtracurricularInfo.SenatePosition
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text("Are you in Student Senate?")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("If yes, what's your position?")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(spacing: 16) {
                ForEach(ExtracurricularInfo.SenatePosition.allCases, id: \.self) { position in
                    Button {
                        selectedPosition = position
                        onNext()
                    } label: {
                        HStack {
                            Image(systemName: position == .none ? "xmark.circle" : "star.circle.fill")
                            Text(position.displayName)
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(position == .none ? .white : MiddlesexTheme.primaryRed)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(position == .none ? Color.white.opacity(0.2) : Color.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

#Preview {
    ExtracurricularQuestionsView(
        selectedClasses: ["A": SchoolClass(name: "Math", department: .math)],
        onComplete: {}
    )
}
