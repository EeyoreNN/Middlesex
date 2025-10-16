//
//  LiveActivityManager.swift
//  Middlesex
//
//  Manager for starting, updating, and stopping Live Activities
//

import Foundation
import ActivityKit
import Combine
import UserNotifications

@available(iOS 16.2, *)
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var currentActivity: Activity<ClassActivityAttributes>?
    private var endCheckTimer: Timer?
    private var specialSchedule: SpecialSchedule?
    private var pushTokenObserver: Task<Void, Never>?

    private init() {
        // Resume existing activities when app launches
        Task {
            await restoreExistingActivity()
        }
    }

    // Restore any existing Live Activity
    private func restoreExistingActivity() async {
        // Fetch special schedule FIRST before validating existing activities
        let cloudKitManager = CloudKitManager.shared
        specialSchedule = await cloudKitManager.fetchSpecialSchedule(for: Date())

        if let special = specialSchedule {
            print("📅 Loaded special schedule on launch: \(special.title)")
        }

        // Get current block using special schedule
        let todaySchedule = DailySchedule.getSchedule(for: Date(), specialSchedule: specialSchedule)
        let currentBlock = todaySchedule.first { $0.isHappeningNow(at: Date()) }

        for activity in Activity<ClassActivityAttributes>.activities {
            let state = activity.content.state
            let endDate = state.endDate
            let now = Date()

            print("📱 Found existing Live Activity: \(activity.id)")
            print("   Showing: \(activity.attributes.className) (\(activity.attributes.block))")
            print("   End date: \(endDate)")
            print("   Current time: \(now)")

            // If activity already expired, end it and check for current class
            if endDate <= now {
                print("   ⚠️ Activity has expired, ending it...")
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            // Check if this Live Activity is showing the correct block
            if let currentBlock = currentBlock {
                print("   📚 Actual current block: \(currentBlock.block)")

                if activity.attributes.block != currentBlock.block {
                    print("   ⚠️ Live Activity showing wrong block!")
                    print("   Expected: \(currentBlock.block), Showing: \(activity.attributes.block)")
                    print("   🔄 Ending incorrect activity and starting correct one...")

                    // Stop the incorrect activity immediately
                    await activity.end(nil, dismissalPolicy: .immediate)

                    await MainActor.run {
                        currentActivity = nil
                    }

                    // Start correct Live Activity with proper time remaining
                    await MainActor.run {
                        print("   🚀 Starting correct activity for block: \(currentBlock.block)")
                        startNewActivityForBlock(currentBlock)
                    }
                    return
                }
            }

            // Activity is still valid and correct
            currentActivity = activity
            print("   ✅ Restored active Live Activity (correct block)")
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
            // Request Live Activity with push notification support
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: endDate),
                pushType: .token
            )

            currentActivity = activity
            print("✅ Live Activity started: \(activity.id)")
            print("   Will end at: \(endDate)")

            // Start monitoring for push token
            startPushTokenMonitoring(for: activity, endDate: endDate)

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

    // Monitor push token and schedule background update
    private func startPushTokenMonitoring(for activity: Activity<ClassActivityAttributes>, endDate: Date) {
        // Cancel any existing observer
        pushTokenObserver?.cancel()

        // Monitor push token changes
        pushTokenObserver = Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                print("📱 Live Activity Push Token: \(tokenString)")

                // Schedule background task to update Live Activity when class ends
                await scheduleActivityUpdate(
                    pushToken: tokenString,
                    activityId: activity.id,
                    endDate: endDate
                )
            }
        }
    }

    // Schedule background notification to update Live Activity
    private func scheduleActivityUpdate(pushToken: String, activityId: String, endDate: Date) async {
        // Calculate time until class ends
        let timeUntilEnd = endDate.timeIntervalSince(Date())

        guard timeUntilEnd > 0 else {
            print("⚠️ Class already ended, not scheduling update")
            return
        }

        print("⏰ Scheduling Live Activity update for \(timeUntilEnd) seconds from now")

        // Schedule local notification to trigger at end time
        // This will update the Live Activity even if app is closed
        let content = UNMutableNotificationContent()
        content.title = "Class Ended"
        content.body = "Checking for next class..."
        content.sound = nil // Silent
        content.interruptionLevel = .passive

        // Add data for the notification handler
        content.userInfo = [
            "type": "liveActivityUpdate",
            "activityId": activityId,
            "pushToken": pushToken
        ]

        // Schedule for when class ends
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeUntilEnd,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "liveActivity_\(activityId)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled Live Activity update notification")
        } catch {
            print("❌ Failed to schedule update: \(error)")
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

    // Check if user participates in this non-class block
    private func userParticipatesInBlock(_ blockName: String) -> Bool {
        let preferences = UserPreferences.shared
        let extracurricular = preferences.extracurricularInfo

        switch blockName {
        case "ChChor":
            // Only show Chapel Chorus if user is in it
            return extracurricular.isInChapelChorus
        case "Senate":
            // Only show Senate if user has a position
            return extracurricular.senatePosition != ExtracurricularInfo.SenatePosition.none
        default:
            // All other blocks (Chapel, Lunch, Athlet, etc.) everyone attends
            return true
        }
    }

    // Stop the current Live Activity
    func stopCurrentActivity(dismissAfter: TimeInterval = 30) {
        endCheckTimer?.invalidate()
        endCheckTimer = nil
        pushTokenObserver?.cancel()
        pushTokenObserver = nil

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

    // Stop the current Live Activity (async version that waits for completion)
    func stopCurrentActivityAsync(dismissAfter: TimeInterval = 30) async {
        endCheckTimer?.invalidate()
        endCheckTimer = nil
        pushTokenObserver?.cancel()
        pushTokenObserver = nil

        guard let activity = currentActivity else { return }

        // Keep it on Lock Screen for specified time after ending
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

    // Check if we should start a Live Activity based on current schedule
    func checkAndStartActivityIfNeeded() {
        print("🔍 Checking if Live Activity should start...")

        // Fetch special schedule first, then check
        Task {
            await fetchSpecialScheduleAndCheck()
        }
    }

    private func fetchSpecialScheduleAndCheck() async {
        // Fetch special schedule for today FIRST
        let cloudKitManager = CloudKitManager.shared
        specialSchedule = await cloudKitManager.fetchSpecialSchedule(for: Date())

        if let special = specialSchedule {
            print("   📅 Using special schedule: \(special.title)")
        } else {
            print("   📅 Using regular schedule")
        }

        await MainActor.run {
            performActivityCheck()
        }
    }

    private func performActivityCheck() {
        // Get current block using special schedule if available
        let todaySchedule = DailySchedule.getSchedule(for: Date(), specialSchedule: specialSchedule)
        let currentBlock = todaySchedule.first { $0.isHappeningNow(at: Date()) }

        // First, validate existing Live Activity if one exists
        if let existingActivity = currentActivity {
            let existingBlock = existingActivity.attributes.block
            let existingClassName = existingActivity.attributes.className

            print("   📱 Existing Live Activity found:")
            print("      Block: \(existingBlock)")
            print("      Class: \(existingClassName)")

            // Check if it's still correct
            guard let currentBlock = currentBlock else {
                print("   ⚠️ No current block - stopping existing activity")
                stopCurrentActivity()
                return
            }

            // If the block changed, update the Live Activity
            if existingBlock != currentBlock.block {
                print("   🔄 Block changed from \(existingBlock) to \(currentBlock.block)")
                print("   Stopping old activity and starting new one...")

                // Stop old activity and start new one asynchronously
                Task {
                    await stopCurrentActivityAsync(dismissAfter: 0)

                    // Now start the correct activity with proper time remaining
                    await MainActor.run {
                        startNewActivityForBlock(currentBlock)
                    }
                }
                return
            } else {
                print("   ✅ Existing Live Activity is correct for current block")
                return
            }
        }

        guard let currentBlock = currentBlock else {
            // No current block, stop any existing activity
            print("   ℹ️ No current block - stopping any existing activity")
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        print("   📚 Current block: \(currentBlock.block) (\(currentBlock.startTime) - \(currentBlock.endTime))")

        // Start new activity for this block
        startNewActivityForBlock(currentBlock)
    }

    private func startNewActivityForBlock(_ currentBlock: BlockTime) {

        // Get user's class for this block
        let blockLetter = String(currentBlock.block.prefix(1))
        let blockToPeriod: [String: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
        ]

        // Check if this is a non-class period (Meet, Lunch, Break, etc.)
        let nonClassBlocks = ["Meet", "Lunch", "Break", "Chapel", "Senate", "Athlet", "CommT", "Announ", "ChChor", "FacMtg"]

        if nonClassBlocks.contains(currentBlock.block) {
            print("   📍 Non-class period: \(currentBlock.block)")

            // Check if user participates in this activity
            if !userParticipatesInBlock(currentBlock.block) {
                print("   ℹ️ User does not participate in \(currentBlock.block) - treating as free period")
                return
            }

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
