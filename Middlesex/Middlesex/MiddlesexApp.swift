//
//  MiddlesexApp.swift
//  Middlesex
//
//  Created by Nick Noon on 10/6/25.
//

import SwiftUI
import CloudKit

@main
struct MiddlesexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var userPreferences = UserPreferences.shared
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .environmentObject(userPreferences)
                .onAppear {
                    if #available(iOS 16.2, *) {
                        liveActivityManager.checkAndStartActivityIfNeeded()
                    }

                    if userPreferences.hasCompletedOnboarding {
                        Task {
                            await notificationManager.requestPermissions()
                            await cloudKitManager.subscribeToAnnouncementUpdates()
                        }
                    }

                    Task {
                        await cloudKitManager.prefetchUpcomingSpecialSchedules()
                        await cloudKitManager.refreshPermanentAdmins(force: true)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        if #available(iOS 16.2, *) {
                            liveActivityManager.checkAndStartActivityIfNeeded()
                        }

                        Task {
                            await cloudKitManager.refreshPermanentAdmins()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    if #available(iOS 16.2, *) {
                        liveActivityManager.checkAndStartActivityIfNeeded()
                    }

                    Task {
                        await cloudKitManager.refreshPermanentAdmins()
                    }
                }
        }
    }
}
