//
//  UserPreferences.swift
//  Middlesex
//
//  User preferences and schedule storage
//

import Foundation
import SwiftUI
import Combine

class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isSignedIn") var isSignedIn: Bool = false
    @AppStorage("userIdentifier") var userIdentifier: String = "" // Apple User ID
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userGrade") var userGrade: String = ""
    @AppStorage("isAdmin") var isAdmin: Bool = false

    // Notification preferences
    @AppStorage("notificationsNextClass") var notificationsNextClass: Bool = true {
        didSet { syncNotificationPreferencesToCloudKit() }
    }
    @AppStorage("notificationsSportsUpdates") var notificationsSportsUpdates: Bool = true {
        didSet { syncNotificationPreferencesToCloudKit() }
    }
    @AppStorage("notificationsAnnouncements") var notificationsAnnouncements: Bool = true {
        didSet { syncNotificationPreferencesToCloudKit() }
    }

    // Store user's class schedule as JSON
    @Published var redWeekSchedule: [Int: UserClass] = [:] {
        didSet {
            saveSchedule(redWeekSchedule, key: "redWeekSchedule")
        }
    }

    @Published var whiteWeekSchedule: [Int: UserClass] = [:] {
        didSet {
            saveSchedule(whiteWeekSchedule, key: "whiteWeekSchedule")
        }
    }

    // Cached special schedules (stored as JSON)
    @Published var cachedSpecialSchedules: [Date: SpecialSchedule] = [:] {
        didSet {
            saveCachedSpecialSchedules()
        }
    }

    private init() {
        loadSchedules()
        loadCachedSpecialSchedules()
    }

    private func saveSchedule(_ schedule: [Int: UserClass], key: String) {
        if let encoded = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func loadSchedules() {
        if let redData = UserDefaults.standard.data(forKey: "redWeekSchedule"),
           let decoded = try? JSONDecoder().decode([Int: UserClass].self, from: redData) {
            redWeekSchedule = decoded
        }

        if let whiteData = UserDefaults.standard.data(forKey: "whiteWeekSchedule"),
           let decoded = try? JSONDecoder().decode([Int: UserClass].self, from: whiteData) {
            whiteWeekSchedule = decoded
        }
    }

    private func saveCachedSpecialSchedules() {
        // Convert Date keys to String for JSON encoding
        let stringKeyDict = Dictionary(uniqueKeysWithValues: cachedSpecialSchedules.map { (key, value) in
            (key.timeIntervalSince1970.description, value)
        })

        if let encoded = try? JSONEncoder().encode(stringKeyDict) {
            UserDefaults.standard.set(encoded, forKey: "cachedSpecialSchedules")
        }
    }

    private func loadCachedSpecialSchedules() {
        if let data = UserDefaults.standard.data(forKey: "cachedSpecialSchedules"),
           let stringKeyDict = try? JSONDecoder().decode([String: SpecialSchedule].self, from: data) {
            // Convert String keys back to Date
            var tempDict: [Date: SpecialSchedule] = [:]
            for (key, value) in stringKeyDict {
                if let timestamp = TimeInterval(key) {
                    tempDict[Date(timeIntervalSince1970: timestamp)] = value
                }
            }
            cachedSpecialSchedules = tempDict
        }
    }

    // Get cached special schedule for a specific date
    func getCachedSpecialSchedule(for date: Date) -> SpecialSchedule? {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        return cachedSpecialSchedules[dateKey]
    }

    // Cache a special schedule
    func cacheSpecialSchedule(_ schedule: SpecialSchedule, for date: Date) {
        let calendar = Calendar.current
        let dateKey = calendar.startOfDay(for: date)
        cachedSpecialSchedules[dateKey] = schedule
    }

    // Remove old cached schedules (older than 1 day)
    func cleanOldCachedSchedules() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        cachedSpecialSchedules = cachedSpecialSchedules.filter { date, _ in
            date >= yesterday
        }
    }

    func getClass(for period: Int, weekType: ClassSchedule.WeekType) -> UserClass? {
        switch weekType {
        case .red:
            return redWeekSchedule[period]
        case .white:
            return whiteWeekSchedule[period]
        }
    }
    
    func getClassWithFallback(for period: Int, preferredWeekType: ClassSchedule.WeekType) -> UserClass? {
        if let userClass = getClass(for: period, weekType: preferredWeekType) {
            return userClass
        }
        
        let fallbackWeek: ClassSchedule.WeekType = preferredWeekType == .red ? .white : .red
        return getClass(for: period, weekType: fallbackWeek)
    }

    func setClass(_ userClass: UserClass, for period: Int, weekType: ClassSchedule.WeekType) {
        switch weekType {
        case .red:
            redWeekSchedule[period] = userClass
        case .white:
            whiteWeekSchedule[period] = userClass
        }
    }

    func removeClass(for period: Int, weekType: ClassSchedule.WeekType) {
        switch weekType {
        case .red:
            redWeekSchedule.removeValue(forKey: period)
        case .white:
            whiteWeekSchedule.removeValue(forKey: period)
        }
    }

    func clearAllData() {
        hasCompletedOnboarding = false
        isSignedIn = false
        userIdentifier = ""
        userEmail = ""
        userName = ""
        userGrade = ""
        isAdmin = false
        redWeekSchedule = [:]
        whiteWeekSchedule = [:]
    }

    // MARK: - CloudKit Sync

    func loadNotificationPreferencesFromCloudKit() {
        guard !userIdentifier.isEmpty else { return }

        Task {
            let cloudKitManager = CloudKitManager.shared
            if let preferences = await cloudKitManager.fetchUserPreferences(userId: userIdentifier) {
                await MainActor.run {
                    // Temporarily disable syncing while loading
                    self.notificationsNextClass = preferences.notificationsNextClass
                    self.notificationsSportsUpdates = preferences.notificationsSportsUpdates
                    self.notificationsAnnouncements = preferences.notificationsAnnouncements
                }
            }
        }
    }

    private func syncNotificationPreferencesToCloudKit() {
        guard !userIdentifier.isEmpty else { return }

        Task {
            let cloudKitManager = CloudKitManager.shared
            await cloudKitManager.saveUserPreferences(
                userId: userIdentifier,
                notificationsNextClass: notificationsNextClass,
                notificationsSportsUpdates: notificationsSportsUpdates,
                notificationsAnnouncements: notificationsAnnouncements
            )
        }
    }
}

struct UserClass: Codable, Hashable {
    let className: String
    let teacher: String
    let room: String
    let color: String
    let xBlockDaysRed: [String]?
    let xBlockDaysWhite: [String]?

    init(className: String, teacher: String, room: String, color: String = "#C8102E", xBlockDaysRed: [String]? = nil, xBlockDaysWhite: [String]? = nil) {
        self.className = className
        self.teacher = teacher
        self.room = room
        self.color = color
        self.xBlockDaysRed = xBlockDaysRed
        self.xBlockDaysWhite = xBlockDaysWhite
    }

    // Get X block days for a specific week type
    func xBlockDays(for weekType: ClassSchedule.WeekType) -> [String]? {
        switch weekType {
        case .red:
            return xBlockDaysRed
        case .white:
            return xBlockDaysWhite
        }
    }
}
