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
    @State private var currentTime = Date()
    @State private var currentBlock: BlockTime?
    @State private var nextBlock: BlockTime?
    @State private var userClass: UserClass?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let block = currentBlock, let cls = userClass {
                LiveActivityCard(
                    block: block,
                    userClass: cls,
                    currentTime: currentTime
                )
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
    }

    private func updateCurrentClass() {
        currentBlock = DailySchedule.getCurrentBlock(at: currentTime)
        nextBlock = DailySchedule.getNextBlock(at: currentTime)

        if let block = currentBlock {
            let blockLetter = String(block.block.prefix(1))
            let blockToPeriod: [String: Int] = [
                "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
            ]

            if let period = blockToPeriod[blockLetter] {
                let weekNumber = Calendar.current.component(.weekOfYear, from: currentTime)
                let weekType: ClassSchedule.WeekType = weekNumber % 2 == 0 ? .red : .white
                userClass = preferences.getClassWithFallback(for: period, preferredWeekType: weekType)
            } else {
                userClass = nil
            }
        } else {
            userClass = nil
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
