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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X Block Days - \(weekType.displayName) Week")
                        .font(.headline)

                    Text("Select which days this class uses \(blockLetter)x blocks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isLoadingCrowdData {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Crowd-sourced suggestion banner
            if let crowdDays = crowdSourcedDays, crowdDays != selectedDays {
                HStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested by students")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)

                        Text("\(crowdDays.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Use") {
                        selectedDays = crowdDays
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
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
                            toggleDay(day)
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
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Standard schedule: \(standardDays.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            VStack(spacing: 4) {
                Text(day.prefix(3))
                    .font(.subheadline.bold())
                    .foregroundColor(isSelected ? .white : .primary)

                if isStandard {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.5) : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                } else {
                    Spacer()
                        .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? MiddlesexTheme.primaryRed
                    : Color.gray.opacity(0.15)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isStandard && !isSelected ? Color.gray.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
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
