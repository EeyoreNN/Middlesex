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
        VStack(spacing: 0) {
            if let block = currentBlock,
               let schoolClass = selectedClasses[block],
               let teacher = selectedTeachers[block],
               schoolClass.name != "Free Block" {

                // Progress
                ProgressView(
                    value: Double(currentClassIndex * 2 + (currentWeekType == .red ? 0 : 1)),
                    total: Double(sortedBlocks.count * 2)
                )
                .tint(MiddlesexTheme.primaryRed)
                .padding()
                .background(Color.clear)

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("\(block) Block X Days")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text(schoolClass.name)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))

                            Text("with \(teacher.name)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()

                        // Week type selector
                        Picker("Week", selection: $currentWeekType) {
                            Text("Red Week").tag(ClassSchedule.WeekType.red)
                            Text("White Week").tag(ClassSchedule.WeekType.white)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // X Block day selector
                        XBlockDaySelector(
                            className: schoolClass.name,
                            teacherName: teacher.name,
                            blockLetter: block,
                            weekType: currentWeekType,
                            selectedDays: binding(for: block, weekType: currentWeekType)
                        )
                        .padding(.horizontal)

                        // Navigation buttons
                        HStack(spacing: 16) {
                            if currentClassIndex > 0 || currentWeekType == .white {
                                Button {
                                    goBack()
                                } label: {
                                    Label("Back", systemImage: "chevron.left")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white.opacity(0.2))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }

                            Button {
                                goNext()
                            } label: {
                                Label(isLast ? "Done" : "Next", systemImage: isLast ? "checkmark" : "chevron.right")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(MiddlesexTheme.primaryRed)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
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
        .background(MiddlesexTheme.redGradient.ignoresSafeArea())
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
