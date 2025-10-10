//
//  CurrentClassLiveView.swift
//  Middlesex
//
//  Live Activity-style view showing current class progress
//

import SwiftUI
import Combine

struct CurrentClassLiveView: View {
    @StateObject private var preferences = UserPreferences.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var currentTime = Date()
    @State private var currentBlock: BlockTime?
    @State private var nextBlock: BlockTime?
    @State private var userClass: UserClass?
    @State private var specialSchedule: SpecialSchedule?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let block = currentBlock {
                if let cls = userClass {
                    // Show class with user's schedule
                    LiveActivityCard(
                        block: block,
                        userClass: cls,
                        currentTime: currentTime
                    )
                } else {
                    // Show non-class block (Lunch, Announ, etc.)
                    NonClassBlockCard(
                        block: block,
                        currentTime: currentTime
                    )
                }
            } else if let next = nextBlock {
                UpNextCard(block: next)
            } else {
                NoClassCard()
            }
        }
        .onAppear {
            updateCurrentClass()
        }
        .onReceive(timer) { time in
            currentTime = time
            updateCurrentClass()
        }
        .task {
            // Fetch special schedule for today
            specialSchedule = await cloudKitManager.fetchSpecialSchedule(for: Date())
            updateCurrentClass()
        }
    }

    private func updateCurrentClass() {
        // Use special schedule if available
        let todaySchedule = DailySchedule.getSchedule(for: currentTime, specialSchedule: specialSchedule)
        currentBlock = todaySchedule.first { $0.isHappeningNow(at: currentTime) }
        nextBlock = todaySchedule.first { block in
            guard let start = block.startDate(on: currentTime) else { return false }
            return start > currentTime
        }

        if let block = currentBlock {
            // Check if this is a non-class block
            let nonClassBlocks: Set<String> = [
                "Lunch", "Chapel", "Athlet", "CommT", "FacMtg", "Announ", "Break", "Senate", "Meet", "ChChor"
            ]

            if nonClassBlocks.contains(block.block) {
                // For non-class blocks, don't show a user class
                userClass = nil
                return
            }

            let blockLetter = String(block.block.prefix(1))
            let isXBlock = block.block.count > 1 && block.block.lowercased().hasSuffix("x")
            let blockToPeriod: [String: Int] = [
                "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
            ]

            if let period = blockToPeriod[blockLetter] {
                let weekNumber = Calendar.current.component(.weekOfYear, from: currentTime)
                let weekType: ClassSchedule.WeekType = weekNumber % 2 == 0 ? .red : .white
                let retrievedClass = preferences.getClassWithFallback(for: period, preferredWeekType: weekType)

                // If this is an X block, check if the class uses X blocks on this day
                if isXBlock, let retrievedClass = retrievedClass {
                    let dayName = getCurrentDayName()

                    // Look up the SchoolClass from ClassList to get X block configuration
                    // Must match both name AND block (if block is specified)
                    if let schoolClass = ClassList.availableClasses.first(where: {
                        $0.name == retrievedClass.className && ($0.block == nil || $0.block == blockLetter)
                    }) {
                        // Get the appropriate X block days based on week type
                        let xBlockDays = weekType == .red ? schoolClass.xBlockDaysRed : schoolClass.xBlockDaysWhite

                        // If X block days are defined, check if today is included
                        if let xBlockDays = xBlockDays {
                            if !xBlockDays.contains(dayName) {
                                // This class doesn't use X blocks on this day
                                userClass = nil
                                return
                            }
                        }
                        // If xBlockDays is nil, use standard schedule (show all X blocks for this period)
                    }
                }

                userClass = retrievedClass
            } else {
                userClass = nil
            }
        } else {
            userClass = nil
        }
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

struct LiveActivityCard: View {
    let block: BlockTime
    let userClass: UserClass
    let currentTime: Date

    var progress: Double {
        block.progressPercentage(at: currentTime)
    }

    var timeRemainingText: String {
        let remaining = block.timeRemaining(at: currentTime)
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Color indicator
                Circle()
                    .fill(Color(hex: userClass.color) ?? MiddlesexTheme.primaryRed)
                    .frame(width: 8, height: 8)

                // Class name
                Text(userClass.className)
                    .font(.headline.bold())
                    .foregroundColor(.white)

                Spacer()

                // Time remaining
                Text(timeRemainingText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Teacher and room
            HStack(spacing: 16) {
                Label(userClass.teacher, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Label(userClass.room, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Block and times
                Text("\(block.block) • \(block.startTime)-\(block.endTime)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.2))

                    // Progress
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .background(
            Color(hex: userClass.color)?.opacity(0.95) ?? MiddlesexTheme.primaryRed
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct UpNextCard: View {
    let block: BlockTime

    var timeUntilStart: String {
        guard let start = block.startDate() else { return "" }
        let interval = start.timeIntervalSince(Date())
        let minutes = Int(interval / 60)

        if minutes < 60 {
            return "in \(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "in \(hours)h \(remainingMinutes)m"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(MiddlesexTheme.primaryRed.opacity(0.8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Up Next")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(block.block) Block")
                    .font(.headline)
                    .foregroundColor(MiddlesexTheme.textPrimary)

                Text("\(block.startTime) - \(block.endTime) • \(timeUntilStart)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

struct NonClassBlockCard: View {
    let block: BlockTime
    let currentTime: Date

    var progress: Double {
        block.progressPercentage(at: currentTime)
    }

    var timeRemainingText: String {
        let remaining = block.timeRemaining(at: currentTime)
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private func specialBlockInfo(_ block: String) -> (icon: String, title: String, tint: Color)? {
        switch block {
        case "Lunch":
            return ("fork.knife", "Lunch", Color.orange)
        case "Chapel":
            return ("building.columns", "Chapel", MiddlesexTheme.primaryRed)
        case "Athlet":
            return ("figure.run", "Athletics", Color.green)
        case "CommT":
            return ("person.3", "Community Time", Color.blue)
        case "FacMtg":
            return ("person.2", "Faculty Meeting", Color.gray)
        case "Announ":
            return ("megaphone", "Announcements", MiddlesexTheme.primaryRed)
        case "Break":
            return ("cup.and.saucer", "Break", Color.cyan)
        case "Senate":
            return ("building.columns", "Senate", Color.purple)
        case "Meet":
            return ("calendar", "Meetings", Color.purple)
        case "ChChor":
            return ("music.note", "Chapel Chorus", Color.yellow)
        default:
            return nil
        }
    }

    var body: some View {
        let info = specialBlockInfo(block.block)

        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon
                if let info = info {
                    Image(systemName: info.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 8)
                }

                // Block name
                Text(info?.title ?? block.block)
                    .font(.headline.bold())
                    .foregroundColor(.white)

                Spacer()

                // Time remaining
                Text(timeRemainingText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Times
            HStack(spacing: 16) {
                Text("\(block.startTime) - \(block.endTime)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.white.opacity(0.2))

                    // Progress
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .background(
            info?.tint.opacity(0.95) ?? MiddlesexTheme.primaryRed
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct NoClassCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("No Class Right Now")
                    .font(.headline)
                    .foregroundColor(MiddlesexTheme.textPrimary)

                Text("Enjoy your free time!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 16) {
        CurrentClassLiveView()

        LiveActivityCard(
            block: BlockTime(block: "A", startTime: "8:25", endTime: "9:05"),
            userClass: UserClass(className: "AP Calculus BC", teacher: "Mr. Smith", room: "Math 101", color: "#1E90FF"),
            currentTime: Date()
        )

        UpNextCard(
            block: BlockTime(block: "F", startTime: "9:10", endTime: "9:50")
        )

        NoClassCard()
    }
    .padding()
    .background(MiddlesexTheme.background)
}
