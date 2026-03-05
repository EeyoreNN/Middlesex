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
        Task {
            await restoreExistingActivity()
        }
    }

    // MARK: - Restore

    private func restoreExistingActivity() async {
        let cloudKitManager = CloudKitManager.shared
        specialSchedule = await cloudKitManager.fetchSpecialSchedule(for: Date())

        let todaySchedule = DailySchedule.getSchedule(for: Date(), specialSchedule: specialSchedule)
        let currentBlock = todaySchedule.first { $0.isHappeningNow(at: Date()) }

        for activity in Activity<ClassActivityAttributes>.activities {
            let endDate = activity.content.state.endDate

            // End expired activities
            if endDate <= Date() {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }

            // End activities showing the wrong block
            if let currentBlock = currentBlock,
               activity.attributes.block != currentBlock.block {
                await activity.end(nil, dismissalPolicy: .immediate)
                await MainActor.run {
                    currentActivity = nil
                    startNewActivityForBlock(currentBlock)
                }
                return
            }

            // Restore valid activity
            currentActivity = activity
            scheduleEndCheck(endDate: endDate)
            break
        }

        if currentActivity == nil {
            await MainActor.run {
                checkAndStartActivityIfNeeded()
            }
        }
    }

    // MARK: - Start

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
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else { return }

        // Don't restart if same class is already active
        if let existing = currentActivity,
           existing.attributes.className == className,
           existing.attributes.block == block {
            return
        }

        // Stop any existing activity immediately
        if currentActivity != nil {
            stopCurrentActivity(dismissAfter: 0)
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
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: endDate),
                pushType: .token
            )

            currentActivity = activity
            startPushTokenMonitoring(for: activity, endDate: endDate)
            scheduleEndCheck(endDate: endDate)
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    // MARK: - Push Token

    private func startPushTokenMonitoring(for activity: Activity<ClassActivityAttributes>, endDate: Date) {
        pushTokenObserver?.cancel()

        pushTokenObserver = Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                await scheduleActivityUpdate(
                    pushToken: tokenString,
                    activityId: activity.id,
                    endDate: endDate
                )
            }
        }
    }

    private func scheduleActivityUpdate(pushToken: String, activityId: String, endDate: Date) async {
        let timeUntilEnd = endDate.timeIntervalSince(Date())
        guard timeUntilEnd > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Class Ended"
        content.body = "Checking for next class..."
        content.sound = nil
        content.interruptionLevel = .passive
        content.userInfo = [
            "type": "liveActivityUpdate",
            "activityId": activityId,
            "pushToken": pushToken
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeUntilEnd,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "liveActivity_\(activityId)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - End Check

    private func scheduleEndCheck(endDate: Date) {
        endCheckTimer?.invalidate()

        let timeUntilEnd = endDate.timeIntervalSince(Date())

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

    // MARK: - Stop

    func stopCurrentActivity(dismissAfter: TimeInterval = 30) {
        endCheckTimer?.invalidate()
        endCheckTimer = nil
        pushTokenObserver?.cancel()
        pushTokenObserver = nil

        guard let activity = currentActivity else { return }

        Task {
            let dismissalDate = Date().addingTimeInterval(dismissAfter)
            await activity.end(
                .init(state: activity.content.state, staleDate: nil),
                dismissalPolicy: dismissAfter > 0 ? .after(dismissalDate) : .immediate
            )
            await MainActor.run {
                currentActivity = nil
            }
        }
    }

    func stopCurrentActivityAsync(dismissAfter: TimeInterval = 30) async {
        endCheckTimer?.invalidate()
        endCheckTimer = nil
        pushTokenObserver?.cancel()
        pushTokenObserver = nil

        guard let activity = currentActivity else { return }

        let dismissalDate = Date().addingTimeInterval(dismissAfter)
        await activity.end(
            .init(state: activity.content.state, staleDate: nil),
            dismissalPolicy: dismissAfter > 0 ? .after(dismissalDate) : .immediate
        )
        await MainActor.run {
            currentActivity = nil
        }
    }

    // MARK: - Schedule Check

    func checkAndStartActivityIfNeeded() {
        Task {
            await fetchSpecialScheduleAndCheck()
        }
    }

    private func fetchSpecialScheduleAndCheck() async {
        let cloudKitManager = CloudKitManager.shared
        specialSchedule = await cloudKitManager.fetchSpecialSchedule(for: Date())

        await MainActor.run {
            performActivityCheck()
        }
    }

    private func performActivityCheck() {
        let todaySchedule = DailySchedule.getSchedule(for: Date(), specialSchedule: specialSchedule)
        let currentBlock = todaySchedule.first { $0.isHappeningNow(at: Date()) }

        // Validate existing activity
        if let existingActivity = currentActivity {
            guard let currentBlock = currentBlock else {
                stopCurrentActivity()
                return
            }

            if existingActivity.attributes.block != currentBlock.block {
                Task {
                    await stopCurrentActivityAsync(dismissAfter: 0)
                    await MainActor.run {
                        startNewActivityForBlock(currentBlock)
                    }
                }
            }
            return
        }

        guard let currentBlock = currentBlock else {
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        startNewActivityForBlock(currentBlock)
    }

    // MARK: - Block Helpers

    private func startNewActivityForBlock(_ currentBlock: BlockTime) {
        let blockLetter = String(currentBlock.block.prefix(1))
        let blockToPeriod: [String: Int] = [
            "A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7
        ]

        let nonClassBlocks: Set<String> = [
            "Meet", "Lunch", "Break", "Chapel", "Senate",
            "Athlet", "CommT", "Announ", "ChChor", "FacMtg"
        ]

        if nonClassBlocks.contains(currentBlock.block) {
            if !userParticipatesInBlock(currentBlock.block) { return }

            if let activity = currentActivity,
               activity.attributes.className == currentBlock.block { return }

            guard let startDate = currentBlock.startDate(),
                  let endDate = currentBlock.endDate() else { return }

            startClassActivity(
                className: currentBlock.block,
                teacher: "",
                room: "",
                block: currentBlock.block,
                startTime: currentBlock.startTime,
                endTime: currentBlock.endTime,
                classColor: colorForBlock(currentBlock.block),
                startDate: startDate,
                endDate: endDate
            )
            return
        }

        guard let period = blockToPeriod[blockLetter] else { return }

        let weekNumber = Calendar.current.component(.weekOfYear, from: Date())
        let weekType: ClassSchedule.WeekType = weekNumber % 2 == 0 ? .red : .white
        let preferences = UserPreferences.shared

        guard let userClass = preferences.getClassWithFallback(for: period, preferredWeekType: weekType) else {
            if currentActivity != nil {
                stopCurrentActivity()
            }
            return
        }

        if let activity = currentActivity,
           activity.attributes.className == userClass.className,
           activity.attributes.block == currentBlock.block { return }

        guard let startDate = currentBlock.startDate(),
              let endDate = currentBlock.endDate() else { return }

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

    private func colorForBlock(_ blockName: String) -> String {
        switch blockName {
        case "Lunch": return "#FF9500"
        case "Break": return "#5AC8FA"
        case "Meet": return "#AF52DE"
        case "Chapel": return "#FFD60A"
        case "Senate": return "#BF5AF2"
        case "Athlet": return "#32D74B"
        case "CommT": return "#0A84FF"
        case "Announ": return "#FF453A"
        case "ChChor": return "#FFD60A"
        case "FacMtg": return "#8E8E93"
        default: return "#C8102E"
        }
    }

    private func userParticipatesInBlock(_ blockName: String) -> Bool {
        let preferences = UserPreferences.shared
        let extracurricular = preferences.extracurricularInfo

        switch blockName {
        case "ChChor":
            return extracurricular.isInChapelChorus
        case "Senate":
            return extracurricular.senatePosition != ExtracurricularInfo.SenatePosition.none
        default:
            return true
        }
    }
}
