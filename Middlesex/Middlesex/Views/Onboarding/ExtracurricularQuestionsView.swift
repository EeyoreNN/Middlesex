//
//  ExtracurricularQuestionsView.swift
//  Middlesex
//
//  Questions about chorus, senate, and extended blocks
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
    @State private var extendedBlocks: [String: Set<String>] = [:] // Block -> Set of days

    var totalSteps: Int {
        // 3 for chorus/senate questions + extended blocks for non-free classes
        let nonFreeClassCount = selectedClasses.values.filter { $0.name != "Free Block" }.count
        return 3 + nonFreeClassCount
    }

    var classesForExtendedQuestions: [(String, SchoolClass)] {
        // Get sorted list of blocks with non-free classes
        selectedClasses
            .filter { $0.value.name != "Free Block" }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .tint(MiddlesexTheme.primaryRed)
                .padding()
                .background(Color.white.opacity(0.2))

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
                        onNext: { currentStep += 1 }
                    )
                } else {
                    // Extended block questions for each class
                    let blockIndex = currentStep - 3
                    let classesForQuestions = classesForExtendedQuestions

                    if blockIndex < classesForQuestions.count {
                        let (block, schoolClass) = classesForQuestions[blockIndex]
                        let isLastBlock = blockIndex >= classesForQuestions.count - 1

                        ExtendedBlockQuestionView(
                            block: block,
                            className: schoolClass.name,
                            selectedDays: Binding(
                                get: { extendedBlocks[block] ?? [] },
                                set: { extendedBlocks[block] = $0 }
                            ),
                            onNext: {
                                if isLastBlock {
                                    saveAndComplete()
                                } else {
                                    currentStep += 1
                                }
                            }
                        )
                    } else {
                        // Shouldn't happen, but safety check
                        Color.clear.onAppear {
                            saveAndComplete()
                        }
                    }
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

        // TODO: Save extended blocks info when we implement the data model
        // For now, just complete onboarding
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

// MARK: - Extended Block Question View

struct ExtendedBlockQuestionView: View {
    let block: String
    let className: String
    @Binding var selectedDays: Set<String>
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text("\(block) Block")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Text(className)
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    Text("Does this class use extended blocks (\(block)x)?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    Text("The schedule will automatically show when they occur")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
            }

            VStack(spacing: 16) {
                Button {
                    selectedDays.insert("uses_extended") // Use as a flag
                    onNext()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Yes, it uses extended blocks")
                    }
                    .font(.headline)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MiddlesexTheme.cardBackground)
                    .cornerRadius(12)
                }

                Button {
                    selectedDays.removeAll()
                    onNext()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("No extended blocks")
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

#Preview {
    ExtracurricularQuestionsView(
        selectedClasses: ["A": SchoolClass(name: "Math", department: .math)],
        onComplete: {}
    )
}
