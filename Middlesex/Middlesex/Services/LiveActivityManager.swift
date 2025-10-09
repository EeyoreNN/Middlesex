//
//  LiveActivityManager.swift
//  Middlesex
//
//  Manager for starting, updating, and stopping Live Activities
//

import Foundation
import ActivityKit
import Combine

@available(iOS 16.2, *)
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var currentActivity: Activity<ClassActivityAttributes>?
    private var endCheckTimer: Timer?

    private init() {
        // Resume existing activities when app launches
        Task {
            await restoreExistingActivity()
        }
    }

    // Restore any existing Live Activity
    private func restoreExistingActivity() async {
        for activity in Activity<ClassActivityAttributes>.activities {
            let state = activity.content.state
            let endDate = state.endDate
            let now = Date()

            print("📱 Found existing Live Activity: \(activity.id)")
            print("   End date: \(endDate)")
            print("   Current time: \(now)")

            // If activity already expired, end it and check for current class
            if endDate <= now {
                print("   ⚠️ Activity has expired, ending it...")
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            // Activity is still valid
            currentActivity = activity
            print("   ✅ Restored active Live Activity")
            scheduleEndCheck(endDate: endDate)
            break // Only restore the first one
        }

        // After checking existing activities, see if we need to start a new one
        if currentActivity == nil {
            await MainActor.run {
                checkAndStartActivityIfNeeded()
            }
        }
    }

    // Start Live Activity when class begins
    func startClassActivity(
        className: String,
        teacher: String,
        room: String,
        block: String,
        startTime: String,
        endTime: String,
        classColor: String,
        startDate: Date,
        endDate: Date
    ) {
        print("🎓 startClassActivity called for: \(className)")
        print("   Block: \(block) | Time: \(startTime) - \(endTime)")
        print("   Teacher: \(teacher) | Room: \(room)")
        print("   Start: \(startDate) | End: \(endDate)")

        // Check if Live Activities are enabled
        let authInfo = ActivityAuthorizationInfo()
        print("   Live Activities enabled: \(authInfo.areActivitiesEnabled)")

        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities are not enabled in Settings")
            return
        }

        // Don't restart if same class is already active
        if let existing = currentActivity,
           existing.attributes.className == className,
           existing.attributes.block == block {
            print("ℹ️ Live Activity already running for this class")
            return
        }

        // Stop any different existing activity
        if currentActivity != nil {
            stopCurrentActivity(dismissAfter: 0) // Immediate dismissal for old activity
        }

        let attributes = ClassActivityAttributes(
            className: className,
            teacher: teacher,
            room: room,
            block: block,
            startTime: startTime,
            endTime: endTime,
            classColor: classColor
        )

        let now = Date()
        let clampedStart = min(startDate, endDate)
        let totalDuration = max(endDate.timeIntervalSince(clampedStart), 1)
        let elapsed = now.timeIntervalSince(clampedStart)
        let normalizedProgress = min(max(elapsed / totalDuration, 0), 1)

        let initialState = ClassActivityAttributes.ContentState(
            timeRemaining: max(endDate.timeIntervalSince(now), 0),
            progress: normalizedProgress,
            currentTime: now,
            startDate: clampedStart,
            endDate: endDate
        )

        do {
            // Set staleDate to end of class
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: endDate),
                pushType: nil
            )

            currentActivity = activity
            print("✅ Live Activity started: \(activity.id)")
            print("   Will end at: \(endDate)")

            // Schedule check to end and start next class
            scheduleEndCheck(endDate: endDate)

            // Also schedule a check shortly after class ends to start next class
            let nextCheckInterval = endDate.timeIntervalSince(Date()) + 5
            if nextCheckInterval > 0 {
                Timer.scheduledTimer(withTimeInterval: nextCheckInterval, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        print("⏰ Class ended, checking for next class...")
                        self.checkAndStartActivityIfNeeded()
                    }
                }
            }

        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    // Schedule a timer to check when class ends
    private func scheduleEndCheck(endDate: Date) {
        endCheckTimer?.invalidate()

        // Calculate time until class ends
        let timeUntilEnd = endDate.timeIntervalSince(Date())

        // Only schedule if class hasn't ended yet
        guard timeUntilEnd > 0 else {
            stopCurrentActivity()
            checkAndStartActivityIfNeeded()
            return
        }

        // Schedule timer to fire shortly after class ends
        endCheckTimer = Timer.scheduledTimer(withTimeInterval: timeUntilEnd + 1, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                self.stopCurrentActivity()
                self.checkAndStartActivityIfNeeded()
            }
        }
    }

    // Get color for non-class blocks
    private func getColorForBlock(_ blockName: String) -> String {
        switch blockName {
        case "Lunch": return "#FF9500"  // Orange
        case "Break": return "#5AC8FA"  // Blue
        case "Meet": return "#AF52DE"   // Purple
        case "Chapel": return "#FFD60A" // Yellow
        case "Senate": return "#BF5AF2" // Purple
        case "Athlet": return "#32D74B" // Green
        case "CommT": return "#0A84FF"  // Blue
        case "Announ": return "#FF453A" // Red
        case "ChChor": return "#FFD60A" // Yellow
        case "FacMtg": return "#8E8E93"  // Gray
        default: return "#C8102E"       // Middlesex Red
        }
    }

    // Stop the current Live Activity
    func stopCurrentActivity(dismissAfter: TimeInterval = 30) {
        endCheckTimer?.invalidate()
        endCheckTimer = nil

        guard let activity = currentActivity else { return }

        Task {
            // Keep it on Lock Screen for 30 seconds after ending
            let dismissalDate = Date().addingTimeInterval(dismissAfter)

            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .after(dismissalDate)
            )

            await MainActor.run {
                currentActivity = nil
            }

            print("🛑 Live Activity stopped (will dismiss after \(dismissAfter)s)")
        }
    }

    // Check if we should start a Live Activity based on current schedule
    func checkAndStartActivityIfNeeded() {
        print("🔍 Checking if Live Activity should start...")

        guard let currentBlock = DailySchedule.getCurrentBlock() else {
            // No current block, stop any existing activity
            print("   ℹ️ No current block - stopping any existing activity")
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        print("   📚 Current block: \(currentBlock.block) (\(currentBlock.startTime) - \(currentBlock.endTime))")

        // Get user's class for this block
        let blockLetter = String(currentBlock.block.prefix(1))
        let blockToPeriod: [String: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
        ]

        // Check if this is a non-class period (Meet, Lunch, Break, etc.)
        let nonClassBlocks = ["Meet", "Lunch", "Break", "Chapel", "Senate", "Athlet", "CommT", "Announ", "ChChor", "FacMtg"]

        if nonClassBlocks.contains(currentBlock.block) {
            print("   📍 Non-class period: \(currentBlock.block)")

            // Don't start if already running for this period
            if let activity = currentActivity,
               activity.attributes.className == currentBlock.block {
                print("   ℹ️ Live Activity already running for this period")
                return
            }

            // Start Live Activity for this non-class period
            guard let startDate = currentBlock.startDate(),
                  let endDate = currentBlock.endDate() else {
                print("   ❌ Could not get start/end dates for current block")
                return
            }

            print("   🚀 Starting Live Activity for \(currentBlock.block)...")

            startClassActivity(
                className: currentBlock.block,
                teacher: "",
                room: "",
                block: currentBlock.block,
                startTime: currentBlock.startTime,
                endTime: currentBlock.endTime,
                classColor: getColorForBlock(currentBlock.block),
                startDate: startDate,
                endDate: endDate
            )
            return
        }

        guard let period = blockToPeriod[blockLetter] else {
            print("   ⚠️ Could not map block letter '\(blockLetter)' to period")
            return
        }

        print("   📝 Block letter: \(blockLetter) → Period: \(period)")

        let weekNumber = Calendar.current.component(.weekOfYear, from: Date())
        let weekType: ClassSchedule.WeekType = weekNumber % 2 == 0 ? .red : .white
        let preferences = UserPreferences.shared

        print("   📅 Week type: \(weekType.rawValue)")

        guard let userClass = preferences.getClassWithFallback(for: period, preferredWeekType: weekType) else {
            // No class scheduled, stop any existing activity
            print("   ℹ️ No class found for period \(period) (\(weekType.rawValue) week)")
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        print("   ✅ Found class: \(userClass.className)")

        // Don't start if already running for this class
        if let activity = currentActivity,
           activity.attributes.className == userClass.className,
           activity.attributes.block == currentBlock.block {
            print("   ℹ️ Live Activity already running for this class")
            return
        }

        // Start new Live Activity
        guard let startDate = currentBlock.startDate(),
              let endDate = currentBlock.endDate() else {
            print("   ❌ Could not get start/end dates for current block")
            return
        }

        print("   🚀 Starting Live Activity for \(userClass.className)...")

        startClassActivity(
            className: userClass.className,
            teacher: userClass.teacher,
            room: userClass.room,
            block: currentBlock.block,
            startTime: currentBlock.startTime,
            endTime: currentBlock.endTime,
            classColor: userClass.color,
            startDate: startDate,
            endDate: endDate
        )
    }
}
