//
//  ScheduleView.swift
//  Middlesex
//
//  Class schedule view with Red/White week system
//

import SwiftUI
import Combine

struct ScheduleView: View {
    @StateObject private var preferences = UserPreferences.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var showingEditSchedule = false
    @State private var currentTime = Date()
    @State private var selectedWeekType: ClassSchedule.WeekType = .red
    @State private var specialSchedule: SpecialSchedule?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var currentWeekType: DailySchedule.WeekType {
        DailySchedule.getCurrentWeekType()
    }

    private var currentClassWeekType: ClassSchedule.WeekType {
        switch currentWeekType {
        case .red:
            return .red
        case .white:
            return .white
        }
    }

    private var selectedDailyWeekType: DailySchedule.WeekType {
        switch selectedWeekType {
        case .red:
            return .red
        case .white:
            return .white
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Show special schedule banner if active
                    if let special = specialSchedule {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(.white)
                                Text("Special Schedule Today")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text(special.title)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(MiddlesexTheme.primaryRed)
                        .cornerRadius(12)
                    }

                    Picker("Week", selection: $selectedWeekType) {
                        ForEach(ClassSchedule.WeekType.allCases, id: \.self) { week in
                            Text(week.displayName).tag(week)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Live current class view
                    CurrentClassLiveView()

                    let todaySchedule = DailySchedule.getSchedule(for: currentTime, weekType: selectedDailyWeekType, specialSchedule: specialSchedule)

                    ForEach(todaySchedule) { blockTime in
                        ScheduleBlockCard(
                            blockTime: blockTime,
                            userClass: getUserClassForBlock(blockTime.block),
                            weekType: selectedWeekType
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
            .task {
                await checkForSpecialSchedule()
            }
            .onReceive(timer) { time in
                currentTime = time
            }
            .onAppear {
                selectedWeekType = currentClassWeekType
            }
        }
    }

    private func checkForSpecialSchedule() async {
        specialSchedule = await cloudKitManager.fetchSpecialSchedule(for: Date())
    }

    private func getUserClassForBlock(_ block: String) -> UserClass? {
        let nonAcademicBlocks: Set<String> = [
            "Lunch", "Chapel", "Athlet", "CommT", "FacMtg", "Announ", "Break", "Senate", "Meet", "ChChor"
        ]

        if nonAcademicBlocks.contains(block) {
            return nil
        }

        // Map block names (A, Ax, B, Bx, etc.) to period numbers
        let blockLetter = String(block.prefix(1))
        let isXBlock = block.count > 1 && block.lowercased().hasSuffix("x")

        // Map A->1, B->2, C->3, D->4, E->5, F->6, G->7
        let blockToPeriod: [String: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
        ]

        guard let period = blockToPeriod[blockLetter] else {
            return nil
        }

        let userClass = preferences.getClassWithFallback(for: period, preferredWeekType: selectedWeekType)

        // If this is an X block, check if the class uses X blocks on this day
        if isXBlock, let userClass = userClass {
            let dayName = getCurrentDayName()

            // Look up the SchoolClass from ClassList to get X block configuration
            // Must match both name AND block (if block is specified)
            if let schoolClass = ClassList.availableClasses.first(where: {
                $0.name == userClass.className && ($0.block == nil || $0.block == blockLetter)
            }) {
                // Get the appropriate X block days based on week type
                let xBlockDays = selectedWeekType == .red ? schoolClass.xBlockDaysRed : schoolClass.xBlockDaysWhite

                // If X block days are defined, check if today is included
                if let xBlockDays = xBlockDays {
                    if !xBlockDays.contains(dayName) {
                        // This class doesn't use X blocks on this day
                        return nil
                    }
                }
                // If xBlockDays is nil, use standard schedule (show all X blocks for this period)
            }
        }

        return userClass
    }

    private func getCurrentDayName() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentTime)

        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Monday"
        }
    }
}

struct ScheduleBlockCard: View {
    let blockTime: BlockTime
    let userClass: UserClass?
    let weekType: ClassSchedule.WeekType
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let special = specialBlockInfo(blockTime.block)

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
                let classColor = color(for: userClass.color)

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
                    .fill(classColor)
                    .frame(width: 12, height: 12)
            } else if let special {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: special.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(special.tint.opacity(colorScheme == .dark ? 0.85 : 0.75))
                            .frame(width: 28, height: 28)

                        Text(special.title)
                            .font(.headline)
                            .foregroundColor(MiddlesexTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(special.tint.opacity(colorScheme == .dark ? 0.9 : 0.8))
                    .frame(width: 12, height: 12)
            } else {
                // Empty period or other
                Text("Free Period")
                    .font(.subheadline)
                    .foregroundColor(MiddlesexTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            backgroundFill(for: userClass, specialTint: special?.tint)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(for: userClass, specialTint: special?.tint), lineWidth: 1)
        )
    }
}

private extension ScheduleBlockCard {
    func color(for hex: String) -> Color {
        Color(hex: hex) ?? MiddlesexTheme.primaryRed
    }

    func backgroundFill(for userClass: UserClass?, specialTint: Color?) -> some View {
        let base = MiddlesexTheme.cardBackground
        let overlayColor: Color? = {
            if let userClass {
                return color(for: userClass.color)
            } else if let specialTint {
                return specialTint
            } else {
                return nil
            }
        }()

        return base.overlay(
            overlayColor?.opacity(colorScheme == .dark ? 0.32 : 0.18) ?? Color.clear
        )
    }

    func borderColor(for userClass: UserClass?, specialTint: Color?) -> Color {
        if let userClass {
            let base = color(for: userClass.color)
            return base.opacity(colorScheme == .dark ? 0.8 : 0.5)
        }

        if let specialTint {
            return specialTint.opacity(colorScheme == .dark ? 0.55 : 0.35)
        }

        return MiddlesexTheme.cardBackground.opacity(0.6)
    }

    func specialBlockInfo(_ block: String) -> (icon: String, title: String, tint: Color)? {
        switch block {
        case "Lunch":
            return ("fork.knife", "Lunch", MiddlesexTheme.primaryRed)
        case "Chapel":
            return ("building.columns", "Chapel", MiddlesexTheme.primaryRed)
        case "Athlet":
            return ("figure.run", "Athletics", MiddlesexTheme.primaryRed)
        case "CommT":
            return ("person.3", "Community Time", MiddlesexTheme.primaryRed)
        case "FacMtg":
            return ("person.2", "Faculty Meeting", MiddlesexTheme.primaryRed)
        case "Announ":
            return ("megaphone", "Announcements", MiddlesexTheme.primaryRed)
        case "Break":
            return ("cup.and.saucer", "Break", MiddlesexTheme.primaryRed)
        case "Senate":
            return ("building.columns", "Senate", MiddlesexTheme.primaryRed)
        case "Meet":
            return ("calendar", "Meetings", MiddlesexTheme.primaryRed)
        case "ChChor":
            return ("music.note", "Chapel Chorus", MiddlesexTheme.primaryRed)
        default:
            return nil
        }
    }
}

struct SchedulePeriodCard: View {
    let periodTime: PeriodTime
    let userClass: UserClass?
    let weekType: ClassSchedule.WeekType
    @Environment(\.colorScheme) private var colorScheme

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
                let classColor = color(for: userClass.color)

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
                    .fill(classColor)
                    .frame(width: 12, height: 12)
            } else {
                // Empty period
                Text("Free Period")
                    .font(.subheadline)
                    .foregroundColor(MiddlesexTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            Group {
                if let userClass = userClass {
                    MiddlesexTheme.cardBackground
                        .overlay(
                            color(for: userClass.color)
                                .opacity(colorScheme == .dark ? 0.32 : 0.18)
                        )
                } else {
                    MiddlesexTheme.cardBackground
                }
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(for: userClass), lineWidth: 1)
        )
    }
}

private extension SchedulePeriodCard {
    func color(for hex: String) -> Color {
        Color(hex: hex) ?? MiddlesexTheme.primaryRed
    }

    func borderColor(for userClass: UserClass?) -> Color {
        guard let userClass else { return MiddlesexTheme.cardBackground.opacity(0.65) }
        let base = color(for: userClass.color)
        let opacity = colorScheme == .dark ? 0.8 : 0.5
        return base.opacity(opacity)
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
