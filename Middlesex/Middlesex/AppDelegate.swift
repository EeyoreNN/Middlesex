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
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    // MARK: - APNs Device Token Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        Task {
            await storeDeviceToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Remote Notification Handler

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
           notification.notificationType == .query {
            Task {
                await CloudKitManager.shared.handleAnnouncementPush()
                completionHandler(.newData)
            }
            return
        }

        completionHandler(.noData)
    }

    // MARK: - CloudKit Device Token Storage

    private func storeDeviceToken(_ token: String) async {
        let preferences = UserPreferences.shared
        guard !preferences.userIdentifier.isEmpty else { return }

        let cloudKitManager = CloudKitManager.shared
        await cloudKitManager.saveDeviceToken(token: token, userId: preferences.userIdentifier)
    }
}
