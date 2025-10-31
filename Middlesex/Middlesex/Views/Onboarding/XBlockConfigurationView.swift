//
//  XBlockConfigurationView.swift
//  Middlesex
//
//  X Block day configuration step in onboarding
//

import SwiftUI

struct XBlockConfigurationView: View {
    let selectedClasses: [String: SchoolClass]
    let selectedTeachers: [String: Teacher]
    @Binding var xBlockDaysRed: [String: [String]]
    @Binding var xBlockDaysWhite: [String: [String]]
    let onComplete: () -> Void

    @State private var currentWeekType: ClassSchedule.WeekType = .red
    @State private var currentClassIndex = 0

    var sortedBlocks: [String] {
        selectedClasses.keys.sorted()
    }

    var currentBlock: String? {
        guard currentClassIndex < sortedBlocks.count else { return nil }
        return sortedBlocks[currentClassIndex]
    }

    var body: some View {
        ZStack {
            MiddlesexTheme.redGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let block = currentBlock,
                   let schoolClass = selectedClasses[block],
                   let teacher = selectedTeachers[block],
                   schoolClass.name != "Free Block" {

                    // Progress indicator (matching onboarding style)
                    HStack(spacing: 8) {
                        ForEach(0..<(sortedBlocks.count * 2)) { index in
                            let currentStep = currentClassIndex * 2 + (currentWeekType == .red ? 0 : 1)
                            Circle()
                                .fill(currentStep == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 40)

                    ScrollView {
                        VStack(spacing: 30) {
                            Spacer()
                                .frame(height: 20)

                            // Icon
                            Image(systemName: "calendar.badge.clock")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 70, height: 70)
                                .foregroundColor(.white)

                            // Header
                            VStack(spacing: 8) {
                                Text("\(block) Block")
                                    .font(.title.bold())
                                    .foregroundColor(.white)

                                Text(schoolClass.name)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.9))

                                Text("with \(teacher.name)")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            // Week type selector (styled to match onboarding)
                            VStack(spacing: 12) {
                                Text("Which week?")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                HStack(spacing: 12) {
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            currentWeekType = .red
                                        }
                                    } label: {
                                        Text("Red Week")
                                            .font(.headline)
                                            .foregroundColor(currentWeekType == .red ? MiddlesexTheme.primaryRed : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(currentWeekType == .red ? Color.white : Color.white.opacity(0.2))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(currentWeekType == .red ? 0.3 : 0.1), lineWidth: 1)
                                            )
                                    }

                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            currentWeekType = .white
                                        }
                                    } label: {
                                        Text("White Week")
                                            .font(.headline)
                                            .foregroundColor(currentWeekType == .white ? MiddlesexTheme.primaryRed : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(currentWeekType == .white ? Color.white : Color.white.opacity(0.2))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(currentWeekType == .white ? 0.3 : 0.1), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 30)

                            // X Block day selector
                            XBlockDaySelector(
                                className: schoolClass.name,
                                teacherName: teacher.name,
                                blockLetter: block,
                                weekType: currentWeekType,
                                selectedDays: binding(for: block, weekType: currentWeekType)
                            )
                            .padding(.horizontal, 30)

                            // Navigation buttons
                            HStack(spacing: 16) {
                                if currentClassIndex > 0 || currentWeekType == .white {
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            goBack()
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "chevron.left")
                                            Text("Back")
                                        }
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.white.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }

                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        goNext()
                                    }
                                } label: {
                                    HStack {
                                        Text(isLast ? "Done" : "Next")
                                        Image(systemName: isLast ? "checkmark" : "chevron.right")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .foregroundColor(MiddlesexTheme.primaryRed)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 30)
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    // Skip to complete if no regular classes
                    Color.clear
                        .onAppear {
                            onComplete()
                        }
                }
            }
        }
    }

    private var isLast: Bool {
        currentClassIndex == sortedBlocks.count - 1 && currentWeekType == .white
    }

    private func binding(for block: String, weekType: ClassSchedule.WeekType) -> Binding<[String]> {
        if weekType == .red {
            return Binding(
                get: { xBlockDaysRed[block] ?? [] },
                set: { xBlockDaysRed[block] = $0 }
            )
        } else {
            return Binding(
                get: { xBlockDaysWhite[block] ?? [] },
                set: { xBlockDaysWhite[block] = $0 }
            )
        }
    }

    private func goNext() {
        if currentWeekType == .red {
            // Move to white week for same class
            currentWeekType = .white
        } else {
            // Move to next class, reset to red week
            if currentClassIndex < sortedBlocks.count - 1 {
                currentClassIndex += 1
                currentWeekType = .red
            } else {
                // Finished all classes and both weeks
                onComplete()
            }
        }
    }

    private func goBack() {
        if currentWeekType == .white {
            // Go back to red week for same class
            currentWeekType = .red
        } else {
            // Go back to previous class, white week
            if currentClassIndex > 0 {
                currentClassIndex -= 1
                currentWeekType = .white
            }
        }
    }
}

#Preview {
    XBlockConfigurationView(
        selectedClasses: [
            "A": SchoolClass(name: "AP Calculus BC", department: .math),
            "B": SchoolClass(name: "American Literature", department: .english)
        ],
        selectedTeachers: [
            "A": Teacher(name: "Mr. Smith", department: .math, defaultRoom: "Math 101"),
            "B": Teacher(name: "Ms. Johnson", department: .english, defaultRoom: "English 201")
        ],
        xBlockDaysRed: .constant([:]),
        xBlockDaysWhite: .constant([:]),
        onComplete: {}
    )
}
