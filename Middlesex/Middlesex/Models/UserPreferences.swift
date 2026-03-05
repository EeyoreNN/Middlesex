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
    @AppStorage("userName") var userName: String = "" {
        didSet { syncUserDataToCloudKit() }
    }
    @AppStorage("userGrade") var userGrade: String = "" {
        didSet { syncUserDataToCloudKit() }
    }
    @AppStorage("prefersCelsius") var prefersCelsius: Bool = false {
        didSet { syncUserDataToCloudKit() }
    }
    @AppStorage("isAdmin") var isAdmin: Bool = false
    @AppStorage("hasPermanentAdminAccess") var hasPermanentAdminAccess: Bool = false
    @AppStorage("hasCompletedCloudKitMigration") private var hasCompletedCloudKitMigration: Bool = false

    // Notification preferences
    @AppStorage("notificationsNextClass") var notificationsNextClass: Bool = true {
        didSet { syncUserDataToCloudKit() }
    }
    @AppStorage("notificationsSportsUpdates") var notificationsSportsUpdates: Bool = true {
        didSet { syncUserDataToCloudKit() }
    }
    @AppStorage("notificationsAnnouncements") var notificationsAnnouncements: Bool = true {
        didSet { syncUserDataToCloudKit() }
    }

    // Store user's class schedule as JSON
    @Published var redWeekSchedule: [Int: UserClass] = [:] {
        didSet {
            saveSchedule(redWeekSchedule, key: "redWeekSchedule")
            syncSchedulesToCloudKit()
        }
    }

    @Published var whiteWeekSchedule: [Int: UserClass] = [:] {
        didSet {
            saveSchedule(whiteWeekSchedule, key: "whiteWeekSchedule")
            syncSchedulesToCloudKit()
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

        // Perform CloudKit migration if needed
        Task {
            await performCloudKitMigrationIfNeeded()
        }
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
        hasPermanentAdminAccess = false
        redWeekSchedule = [:]
        whiteWeekSchedule = [:]
    }

    // MARK: - CloudKit Sync

    func loadUserDataFromCloudKit() {
        guard !userIdentifier.isEmpty else { return }

        Task {
            let cloudKitManager = CloudKitManager.shared

            if let userData = await cloudKitManager.fetchUserData(userId: userIdentifier) {
                await MainActor.run {
                    self.userName = userData.userName
                    self.userGrade = userData.userGrade
                    self.prefersCelsius = userData.prefersCelsius
                    self.notificationsNextClass = userData.notificationsNextClass
                    self.notificationsSportsUpdates = userData.notificationsSportsUpdates
                    self.notificationsAnnouncements = userData.notificationsAnnouncements
                }

                if let schedules = await cloudKitManager.fetchUserSchedules(userId: userIdentifier) {
                    await MainActor.run {
                        self.redWeekSchedule = schedules.redWeek
                        self.whiteWeekSchedule = schedules.whiteWeek
                    }
                }
            }
        }
    }

    private func syncUserDataToCloudKit() {
        guard !userIdentifier.isEmpty else { return }

        Task {
            await CloudKitManager.shared.saveUserData(
                userId: userIdentifier,
                userName: userName,
                userGrade: userGrade,
                prefersCelsius: prefersCelsius,
                notificationsNextClass: notificationsNextClass,
                notificationsSportsUpdates: notificationsSportsUpdates,
                notificationsAnnouncements: notificationsAnnouncements
            )
        }
    }

    private func syncSchedulesToCloudKit() {
        guard !userIdentifier.isEmpty else { return }

        Task {
            await CloudKitManager.shared.saveUserSchedules(
                userId: userIdentifier,
                redWeek: redWeekSchedule,
                whiteWeek: whiteWeekSchedule
            )
        }
    }

    // MARK: - CloudKit Migration

    private func performCloudKitMigrationIfNeeded() async {
        guard !hasCompletedCloudKitMigration else { return }
        guard hasCompletedOnboarding, !userIdentifier.isEmpty else { return }

        guard !userName.isEmpty else {
            await MainActor.run {
                hasCompletedCloudKitMigration = true
            }
            return
        }

        await CloudKitManager.shared.saveUserData(
            userId: userIdentifier,
            userName: userName,
            userGrade: userGrade,
            prefersCelsius: prefersCelsius,
            notificationsNextClass: notificationsNextClass,
            notificationsSportsUpdates: notificationsSportsUpdates,
            notificationsAnnouncements: notificationsAnnouncements
        )

        await MainActor.run {
            hasCompletedCloudKitMigration = true
        }
    }

    func resetCloudKitMigration() {
        hasCompletedCloudKitMigration = false
        Task {
            await performCloudKitMigrationIfNeeded()
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
