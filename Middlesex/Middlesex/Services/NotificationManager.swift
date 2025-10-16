//
//  NotificationManager.swift
//  Middlesex
//
//  Manages notification scheduling and permissions
//

import Foundation
import UserNotifications
import Combine
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
    }

    // Setup notification categories
    private func setupNotificationCategories() {
        let nextClassCategory = UNNotificationCategory(
            identifier: "NEXT_CLASS",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let sportsCategory = UNNotificationCategory(
            identifier: "SPORTS_GAME",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let announcementCategory = UNNotificationCategory(
            identifier: "ANNOUNCEMENT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let emergencyCategory = UNNotificationCategory(
            identifier: "EMERGENCY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            nextClassCategory,
            sportsCategory,
            announcementCategory,
            emergencyCategory
        ])

        print("✅ Notification categories configured")
    }

    // Request notification permissions (including Critical Alerts)
    func requestPermissions() async -> Bool {
        do {
            // Request standard notifications plus Critical Alerts
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert]
            )
            print(granted ? "✅ Notification permissions granted (including Critical Alerts)" : "❌ Notification permissions denied")

            if granted {
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }

            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error)")
            return false
        }
    }

    // Send critical alert (bypasses Do Not Disturb)
    func sendCriticalAlert(title: String, body: String, sound: UNNotificationSound = .defaultCritical) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.interruptionLevel = .critical
        content.categoryIdentifier = "EMERGENCY"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🚨 Critical alert sent: \(title)")
        } catch {
            print("❌ Failed to send critical alert: \(error)")
        }
    }

    // Send regular notification (respects Do Not Disturb and Focus modes)
    func sendNotification(title: String, body: String, category: String = "ANNOUNCEMENT") async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive // Important but respects Focus modes
        content.categoryIdentifier = category
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Notification sent: \(title)")
        } catch {
            print("❌ Failed to send notification: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        print("📬 Notification received in foreground: \(notification.request.content.title)")

        // Check if this is a Live Activity update notification
        let userInfo = notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "liveActivityUpdate" {
            print("   → Live Activity update notification received")

            // Trigger Live Activity check on main actor
            await MainActor.run {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.checkAndStartActivityIfNeeded()
                }
            }

            // Don't show this notification to user (it's internal)
            return []
        }

        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("👆 User tapped notification: \(response.notification.request.content.title)")

        // Check if this is a Live Activity update notification
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String, type == "liveActivityUpdate" {
            print("   → Live Activity update triggered")

            // Update Live Activity on main actor
            await MainActor.run {
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.checkAndStartActivityIfNeeded()
                }
            }
            return
        }

        // Handle different notification types
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        switch categoryIdentifier {
        case "NEXT_CLASS":
            print("   → Opening schedule view")
            // TODO: Navigate to schedule
        case "SPORTS_GAME":
            print("   → Opening sports view")
            // TODO: Navigate to sports
        case "ANNOUNCEMENT":
            print("   → Opening announcements view")
            // TODO: Navigate to announcements
        default:
            break
        }
    }

    // Schedule notification for next class
    func scheduleNextClassNotification(className: String, startTime: String, blockName: String, room: String, teacher: String, at date: Date) {
        let preferences = UserPreferences.shared
        guard preferences.notificationsNextClass else { return }

        let content = UNMutableNotificationContent()
        content.title = "Next Class: \(className)"
        content.body = "\(blockName) Block starts at \(startTime) in \(room) with \(teacher)"
        content.sound = .default
        content.categoryIdentifier = "NEXT_CLASS"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "nextClass_\(date.timeIntervalSince1970)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling next class notification: \(error)")
            } else {
                print("✅ Scheduled next class notification for \(className) at \(startTime)")
            }
        }
    }

    // Schedule notification for sports game
    func scheduleSportsGameNotification(sport: String, opponent: String, location: String, gameTime: Date, gameTimeString: String) {
        let preferences = UserPreferences.shared
        guard preferences.notificationsSportsUpdates else { return }

        // Schedule reminder 30 minutes before game
        let reminderTime = gameTime.addingTimeInterval(-30 * 60)
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(sport) Game Starting Soon"
        content.body = "Middlesex vs \(opponent) at \(gameTimeString) (\(location))"
        content.sound = .default
        content.categoryIdentifier = "SPORTS_GAME"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "sportsGame_\(gameTime.timeIntervalSince1970)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling sports game notification: \(error)")
            } else {
                print("✅ Scheduled sports game notification for \(sport) vs \(opponent)")
            }
        }
    }

    // Schedule notification for new announcement
    func scheduleAnnouncementNotification(title: String, message: String) {
        let preferences = UserPreferences.shared
        guard preferences.notificationsAnnouncements else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Announcement: \(title)"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "ANNOUNCEMENT"

        // Deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: "announcement_\(UUID().uuidString)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling announcement notification: \(error)")
            } else {
                print("✅ Scheduled announcement notification: \(title)")
            }
        }
    }

    // Remove all pending notifications
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ Removed all pending notifications")
    }

    // Remove next class notifications
    func removeNextClassNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.starts(with: "nextClass_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            print("🗑️ Removed \(identifiers.count) next class notifications")
        }
    }

    // Remove sports notifications
    func removeSportsNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.starts(with: "sportsGame_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            print("🗑️ Removed \(identifiers.count) sports notifications")
        }
    }

    // Test notification (fires in 5 seconds)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "If you see this, notifications are working!"
        content.sound = .default
        content.categoryIdentifier = "ANNOUNCEMENT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error sending test notification: \(error)")
            } else {
                print("✅ Test notification scheduled - will fire in 5 seconds")
            }
        }
    }
}
