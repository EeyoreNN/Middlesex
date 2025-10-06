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
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var currentActivity: Activity<ClassActivityAttributes>?
    private var updateTimer: Timer?

    private init() {
        // Resume existing activities when app launches
        Task {
            await restoreExistingActivity()
        }
    }

    // Restore any existing Live Activity
    private func restoreExistingActivity() async {
        for activity in Activity<ClassActivityAttributes>.activities {
            currentActivity = activity
            print("📱 Restored existing Live Activity: \(activity.id)")

            // Calculate end date from current state
            let timeRemaining = activity.content.state.timeRemaining
            let endDate = Date().addingTimeInterval(timeRemaining)
            startUpdateTimer(endDate: endDate)
            break // Only restore the first one
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
        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
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

        let initialState = ClassActivityAttributes.ContentState(
            timeRemaining: endDate.timeIntervalSince(Date()),
            progress: 0.0,
            currentTime: Date()
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            print("✅ Live Activity started: \(activity.id)")

            // Start timer to update every 30 seconds
            startUpdateTimer(endDate: endDate)

        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    // Start timer to update Live Activity
    private func startUpdateTimer(endDate: Date) {
        updateTimer?.invalidate()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.updateActivity(endDate: endDate)
            }
        }
    }

    // Update Live Activity with current progress
    private func updateActivity(endDate: Date) async {
        guard let activity = currentActivity else { return }

        let now = Date()
        let totalDuration = endDate.timeIntervalSince(activity.content.state.currentTime)
        let elapsed = now.timeIntervalSince(activity.content.state.currentTime)
        let progress = min(max(elapsed / totalDuration, 0), 1)
        let timeRemaining = max(endDate.timeIntervalSince(now), 0)

        // If class is over, stop the activity
        if timeRemaining <= 0 {
            stopCurrentActivity()
            return
        }

        let updatedState = ClassActivityAttributes.ContentState(
            timeRemaining: timeRemaining,
            progress: progress,
            currentTime: now
        )

        await activity.update(
            .init(state: updatedState, staleDate: nil)
        )
    }

    // Stop the current Live Activity
    func stopCurrentActivity(dismissAfter: TimeInterval = 30) {
        updateTimer?.invalidate()
        updateTimer = nil

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
        guard let currentBlock = DailySchedule.getCurrentBlock() else {
            // No current block, stop any existing activity
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        // Get user's class for this block
        let blockLetter = String(currentBlock.block.prefix(1))
        let blockToPeriod: [String: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
        ]

        guard let period = blockToPeriod[blockLetter] else { return }

        let weekNumber = Calendar.current.component(.weekOfYear, from: Date())
        let weekType: ClassSchedule.WeekType = weekNumber % 2 == 0 ? .red : .white
        let preferences = UserPreferences.shared

        guard let userClass = preferences.getClass(for: period, weekType: weekType) else {
            // No class scheduled, stop any existing activity
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        // Don't start if already running for this class
        if let activity = currentActivity,
           activity.attributes.className == userClass.className,
           activity.attributes.block == currentBlock.block {
            return
        }

        // Start new Live Activity
        guard let startDate = currentBlock.startDate(),
              let endDate = currentBlock.endDate() else {
            return
        }

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
