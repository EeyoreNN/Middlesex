//
//  AppDelegate.swift
//  Middlesex
//
//  Handles APNs device token registration and remote notifications
//

import UIKit
import UserNotifications
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    // MARK: - APNs Device Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert token to hex string
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()

        print("✅ APNs device token: \(token)")

        // Store token in CloudKit for server push targeting
        Task {
            await storeDeviceToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")

        // Common reasons:
        // - Not running on a physical device (simulator doesn't support APNs)
        // - APNs capability not enabled in Xcode project
        // - No APNs certificate or auth key configured
        // - Network connectivity issues
    }

    // MARK: - Remote Notification Handler

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📨 Received remote notification")
        print("   UserInfo: \(userInfo)")

        // Check if this is a CloudKit notification
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            print("☁️ CloudKit notification received")
            print("   Type: \(notification.notificationType.rawValue)")

            // Handle query (subscription) notifications
            if notification.notificationType == .query {
                print("📢 Announcement subscription triggered")

                // Handle the announcement push asynchronously
                Task {
                    await CloudKitManager.shared.handleAnnouncementPush()
                    completionHandler(.newData)
                }
                return
            }
        }

        completionHandler(.noData)
    }

    // MARK: - CloudKit Device Token Storage

    private func storeDeviceToken(_ token: String) async {
        let preferences = UserPreferences.shared
        guard !preferences.userIdentifier.isEmpty else {
            print("⚠️ No user identifier - skipping device token storage")
            return
        }

        let cloudKitManager = CloudKitManager.shared
        await cloudKitManager.saveDeviceToken(token: token, userId: preferences.userIdentifier)
    }
}
