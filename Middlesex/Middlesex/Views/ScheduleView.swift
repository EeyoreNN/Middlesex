//
//  ScheduleView.swift
//  Middlesex
//
//  Class schedule view with Red/White week system
//

import SwiftUI

struct ScheduleView: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var showingEditSchedule = false
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var currentWeekType: ClassSchedule.WeekType {
        DailySchedule.getCurrentWeekType()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Live current class view
                    CurrentClassLiveView()

                    let todaySchedule = DailySchedule.getSchedule(for: currentTime, weekType: currentWeekType)

                    ForEach(todaySchedule) { blockTime in
                        ScheduleBlockCard(
                            blockTime: blockTime,
                            userClass: getUserClassForBlock(blockTime.block),
                            weekType: currentWeekType
                        )
                    }

                    Spacer(minLength: 80)
                }
                .padding()
            }
            .background(MiddlesexTheme.background)
            .navigationTitle("Today's Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditSchedule = true
                    } label: {
                        Text("Edit")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                }
            }
            .sheet(isPresented: $showingEditSchedule) {
                ScheduleEditorView()
            }
            .onReceive(timer) { time in
                currentTime = time
            }
        }
    }

    private func getUserClassForBlock(_ block: String) -> UserClass? {
        // Map block names (A, Ax, B, Bx, etc.) to period numbers
        let blockLetter = String(block.prefix(1))

        // Map A->1, B->2, C->3, D->4, E->5, F->6, G->7
        let blockToPeriod: [String: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
        ]

        guard let period = blockToPeriod[blockLetter] else {
            return nil
        }

        return preferences.getClass(for: period, weekType: currentWeekType)
    }
}

struct ScheduleBlockCard: View {
    let blockTime: BlockTime
    let userClass: UserClass?
    let weekType: ClassSchedule.WeekType

    var body: some View {
        HStack(spacing: 16) {
            // Block name and time
            VStack(spacing: 4) {
                Text(blockTime.block)
                    .font(.title2.bold())
                    .foregroundColor(weekType == .red ? MiddlesexTheme.redWeekColor : MiddlesexTheme.whiteWeekColor)

                Text(blockTime.startTime)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(blockTime.endTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)

            if let userClass = userClass {
                // Class information
                VStack(alignment: .leading, spacing: 6) {
                    Text(userClass.className)
                        .font(.headline)
                        .foregroundColor(MiddlesexTheme.textPrimary)

                    HStack(spacing: 12) {
                        Label(userClass.teacher, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Label(userClass.room, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Color indicator
                Circle()
                    .fill(Color(hex: userClass.color) ?? MiddlesexTheme.primaryRed)
                    .frame(width: 12, height: 12)
            } else if blockTime.block == "Lunch" {
                // Lunch period
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.secondary)
                    Text("Lunch")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "Chapel" {
                // Chapel
                HStack {
                    Image(systemName: "building.columns")
                        .foregroundColor(.secondary)
                    Text("Chapel")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "Athlet" {
                // Athletics
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundColor(.secondary)
                    Text("Athletics")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "CommT" {
                // Community Time
                HStack {
                    Image(systemName: "person.3")
                        .foregroundColor(.secondary)
                    Text("Community Time")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "FacMtg" {
                // Faculty Meeting
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.secondary)
                    Text("Faculty Meeting")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "Announ" {
                // Announcements
                HStack {
                    Image(systemName: "megaphone")
                        .foregroundColor(.secondary)
                    Text("Announcements")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "Break" {
                // Break
                HStack {
                    Image(systemName: "cup.and.saucer")
                        .foregroundColor(.secondary)
                    Text("Break")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "Senate" {
                // Senate
                HStack {
                    Image(systemName: "building.columns")
                        .foregroundColor(.secondary)
                    Text("Senate")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "Meet" {
                // Meetings
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("Meetings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if blockTime.block == "ChChor" {
                // Chapel Chorus
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                    Text("Chapel Chorus")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Empty period or other
                Text("Free Period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            userClass != nil
                ? Color(hex: userClass!.color)?.opacity(0.1) ?? Color.white
                : Color.white
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    userClass != nil
                        ? Color(hex: userClass!.color)?.opacity(0.3) ?? Color.clear
                        : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

struct SchedulePeriodCard: View {
    let periodTime: PeriodTime
    let userClass: UserClass?
    let weekType: ClassSchedule.WeekType

    var body: some View {
        HStack(spacing: 16) {
            // Period number and time
            VStack(spacing: 4) {
                Text("\(periodTime.period)")
                    .font(.title2.bold())
                    .foregroundColor(weekType == .red ? MiddlesexTheme.redWeekColor : MiddlesexTheme.whiteWeekColor)

                Text(periodTime.startTime)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(periodTime.endTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)

            if let userClass = userClass {
                // Class information
                VStack(alignment: .leading, spacing: 6) {
                    Text(userClass.className)
                        .font(.headline)
                        .foregroundColor(MiddlesexTheme.textPrimary)

                    HStack(spacing: 12) {
                        Label(userClass.teacher, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Label(userClass.room, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Color indicator
                Circle()
                    .fill(Color(hex: userClass.color) ?? MiddlesexTheme.primaryRed)
                    .frame(width: 12, height: 12)
            } else {
                // Empty period
                Text("Free Period")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            userClass != nil
                ? Color(hex: userClass!.color)?.opacity(0.1) ?? Color.white
                : Color.white
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    userClass != nil
                        ? Color(hex: userClass!.color)?.opacity(0.3) ?? Color.clear
                        : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

struct ScheduleEditorView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScheduleBuilderView(onComplete: {
                dismiss()
            })
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ScheduleView()
}
