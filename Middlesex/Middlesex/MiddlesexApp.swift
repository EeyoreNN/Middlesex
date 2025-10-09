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
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var userPreferences = UserPreferences.shared
    @StateObject private var liveActivityManager: LiveActivityManager = {
        if #available(iOS 16.2, *) {
            return LiveActivityManager.shared
        } else {
            // Fallback for older iOS versions
            return LiveActivityManager.shared
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudKitManager)
                .environmentObject(userPreferences)
                .onAppear {
                    // Check and start Live Activity when app opens
                    if #available(iOS 16.2, *) {
                        liveActivityManager.checkAndStartActivityIfNeeded()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    // Re-check Live Activity when app becomes active
                    if newPhase == .active {
                        if #available(iOS 16.2, *) {
                            liveActivityManager.checkAndStartActivityIfNeeded()
                        }
                    }
                }
        }
    }
}
