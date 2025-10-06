//
//  ScheduleBuilderView.swift
//  Middlesex
//
//  Schedule builder for Red/White week classes
//

import SwiftUI
import UIKit

struct ScheduleBuilderView: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var selectedWeek: ClassSchedule.WeekType = .red
    @State private var showingAddClass = false
    @State private var selectedPeriod: Int?

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Build Your Schedule")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Week selector
                HStack(spacing: 0) {
                    ForEach(ClassSchedule.WeekType.allCases, id: \.self) { week in
                        Button {
                            selectedWeek = week
                        } label: {
                            VStack(spacing: 8) {
                                Text(week.displayName)
                                    .font(.headline)
                                    .foregroundColor(selectedWeek == week ? .white : .white.opacity(0.6))

                                if selectedWeek == week {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(height: 2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)

            // Schedule list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PeriodTime.defaultSchedule) { periodTime in
                        PeriodRow(
                            periodTime: periodTime,
                            userClass: preferences.getClass(for: periodTime.period, weekType: selectedWeek),
                            onTap: {
                                selectedPeriod = periodTime.period
                                showingAddClass = true
                            },
                            onDelete: {
                                preferences.removeClass(for: periodTime.period, weekType: selectedWeek)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color.white)
            .cornerRadius(30, corners: [.topLeft, .topRight])

            // Complete button
            Button {
                onComplete()
            } label: {
                Text("Complete Setup")
                    .font(.headline)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .background(MiddlesexTheme.redGradient.ignoresSafeArea())
        .sheet(isPresented: $showingAddClass) {
            if let period = selectedPeriod {
                AddClassView(
                    period: period,
                    weekType: selectedWeek,
                    existingClass: preferences.getClass(for: period, weekType: selectedWeek)
                )
            }
        }
    }
}

struct PeriodRow: View {
    let periodTime: PeriodTime
    let userClass: UserClass?
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Period number
            VStack {
                Text("\(periodTime.period)")
                    .font(.title3.bold())
                    .foregroundColor(MiddlesexTheme.primaryRed)

                Text(periodTime.startTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)

            if let userClass = userClass {
                // Class info
                VStack(alignment: .leading, spacing: 4) {
                    Text(userClass.className)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(userClass.teacher)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Room \(userClass.room)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                }
            } else {
                // Empty state
                Button(action: onTap) {
                    HStack {
                        Text("Add Class")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(userClass != nil ? Color(hex: userClass!.color)?.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if userClass != nil {
                onTap()
            }
        }
    }
}

struct AddClassView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared

    let period: Int
    let weekType: ClassSchedule.WeekType
    let existingClass: UserClass?

    @State private var className = ""
    @State private var teacher = ""
    @State private var room = ""
    @State private var selectedColor = "#C8102E"

    let colors = [
        "#C8102E", // Middlesex Red
        "#E74C3C", // Red
        "#3498DB", // Blue
        "#2ECC71", // Green
        "#F39C12", // Orange
        "#9B59B6", // Purple
        "#1ABC9C", // Teal
        "#E67E22"  // Dark Orange
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Class Information") {
                    TextField("Class Name", text: $className)
                    TextField("Teacher", text: $teacher)
                    TextField("Room Number", text: $room)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color) ?? MiddlesexTheme.primaryRed)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Period \(period)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveClass()
                    }
                    .disabled(className.isEmpty || teacher.isEmpty || room.isEmpty)
                }
            }
        }
        .onAppear {
            if let existing = existingClass {
                className = existing.className
                teacher = existing.teacher
                room = existing.room
                selectedColor = existing.color
            }
        }
    }

    private func saveClass() {
        let newClass = UserClass(
            className: className,
            teacher: teacher,
            room: room,
            color: selectedColor
        )
        preferences.setClass(newClass, for: period, weekType: weekType)
        dismiss()
    }
}

// Helper extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Helper extension for hex colors
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    ScheduleBuilderView(onComplete: {})
}
