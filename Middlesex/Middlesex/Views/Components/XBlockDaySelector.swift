//
//  XBlockDaySelector.swift
//  Middlesex
//
//  UI component for selecting which days a class uses X blocks
//

import SwiftUI

struct XBlockDaySelector: View {
    let className: String
    let teacherName: String
    let blockLetter: String
    let weekType: ClassSchedule.WeekType
    @Binding var selectedDays: [String]

    @State private var crowdSourcedDays: [String]?
    @State private var isLoadingCrowdData = false

    private let allDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Select X Block Days")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Which days does this class meet for \(blockLetter)x blocks?")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Crowd-sourced suggestion banner
            if let crowdDays = crowdSourcedDays, crowdDays != selectedDays {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDays = crowdDays
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggested by other students")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)

                            Text("\(crowdDays.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Text("Use")
                            .font(.headline)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            // Day selection buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(allDays, id: \.self) { day in
                    DayToggleButton(
                        day: day,
                        isSelected: selectedDays.contains(day),
                        isStandard: isStandardDay(day),
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                toggleDay(day)
                            }
                        }
                    )
                }
            }

            // Standard schedule indicator
            let standardDays = XBlockScheduleResolver.getStandardXBlockDays(
                for: blockLetter,
                weekType: weekType
            )

            if !standardDays.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Text("Typical schedule: \(standardDays.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if isLoadingCrowdData {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text("Loading suggestions...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .task {
            await loadCrowdSourcedData()
        }
    }

    private func toggleDay(_ day: String) {
        if selectedDays.contains(day) {
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
        }
    }

    private func isStandardDay(_ day: String) -> Bool {
        let standardDays = XBlockScheduleResolver.getStandardXBlockDays(
            for: blockLetter,
            weekType: weekType
        )
        return standardDays.contains(day)
    }

    private func loadCrowdSourcedData() async {
        isLoadingCrowdData = true

        crowdSourcedDays = await XBlockScheduleResolver.fetchPopularXBlockDays(
            className: className,
            teacherName: teacherName,
            weekType: weekType
        )

        // Auto-populate if user hasn't selected anything yet and crowd data exists
        if selectedDays.isEmpty, let crowdDays = crowdSourcedDays {
            selectedDays = crowdDays
        }

        isLoadingCrowdData = false
    }
}

struct DayToggleButton: View {
    let day: String
    let isSelected: Bool
    let isStandard: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(day.prefix(3))
                    .font(.headline)
                    .foregroundColor(isSelected ? MiddlesexTheme.primaryRed : .white)

                if isStandard {
                    Circle()
                        .fill(isSelected ? MiddlesexTheme.primaryRed.opacity(0.6) : Color.white.opacity(0.5))
                        .frame(width: 5, height: 5)
                } else {
                    Spacer()
                        .frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.white.opacity(isSelected ? 0.3 : 0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 24) {
        XBlockDaySelector(
            className: "AP Calculus BC",
            teacherName: "Mr. Smith",
            blockLetter: "F",
            weekType: .red,
            selectedDays: .constant(["Monday", "Thursday"])
        )

        XBlockDaySelector(
            className: "American Literature",
            teacherName: "Ms. Johnson",
            blockLetter: "B",
            weekType: .white,
            selectedDays: .constant([])
        )
    }
    .padding()
    .background(MiddlesexTheme.background)
}
