//
//  CloudKitManager.swift
//  Middlesex
//
//  CloudKit manager for fetching and syncing data
//

import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let publicDatabase: CKDatabase

    @Published var menuItems: [MenuItem] = []
    @Published var announcements: [Announcement] = []
    @Published var sportsEvents: [SportsEvent] = []
    @Published var sportsTeams: [SportsTeam] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        // CloudKit container identifier matching entitlements
        container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
        publicDatabase = container.publicCloudDatabase

        // Check iCloud account status
        Task {
            await checkAccountStatus()
        }
    }

    // Check if user is signed into iCloud
    private func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                print("✅ iCloud account available")
            case .noAccount:
                print("⚠️ No iCloud account - User needs to sign in to iCloud in Settings")
            case .restricted:
                print("⚠️ iCloud account restricted")
            case .couldNotDetermine:
                print("⚠️ Could not determine iCloud account status")
            case .temporarilyUnavailable:
                print("⚠️ iCloud account temporarily unavailable")
            @unknown default:
                print("⚠️ Unknown iCloud account status")
            }
        } catch {
            print("❌ Error checking iCloud account status: \(error)")
        }
    }

    // MARK: - Menu Items

    func fetchMenuItems(for date: Date, mealType: MenuItem.MealType? = nil) async {
        isLoading = true
        errorMessage = nil

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        var predicates: [NSPredicate] = [
            NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        ]

        if let mealType = mealType {
            predicates.append(NSPredicate(format: "mealType == %@", mealType.rawValue))
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let query = CKQuery(recordType: "MenuItem", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "category", ascending: true)]

        do {
            let results = try await publicDatabase.records(matching: query)
            let items = results.matchResults.compactMap { try? $0.1.get() }.compactMap { MenuItem(record: $0) }
            self.menuItems = items
        } catch {
            errorMessage = "Failed to fetch menu: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Announcements

    func fetchActiveAnnouncements() async {
        isLoading = true
        errorMessage = nil

        let now = Date()
        print("🔍 Fetching announcements with date: \(now)")

        let predicate = NSPredicate(
            format: "isActive == 1 AND publishDate <= %@ AND expiryDate >= %@",
            now as NSDate, now as NSDate
        )
        print("🔍 Query predicate: \(predicate)")

        let query = CKQuery(recordType: "Announcement", predicate: predicate)
        query.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "publishDate", ascending: false)
        ]

        do {
            let results = try await publicDatabase.records(matching: query)
            print("🔍 Found \(results.matchResults.count) raw results")

            let items = results.matchResults.compactMap { result -> Announcement? in
                do {
                    let record = try result.1.get()
                    print("📝 Record: \(record.recordID.recordName)")
                    print("   - publishDate: \(record["publishDate"] as? Date ?? Date())")
                    print("   - expiryDate: \(record["expiryDate"] as? Date ?? Date())")
                    print("   - isActive: \(record["isActive"] as? Int64 ?? 0)")

                    if let announcement = Announcement(record: record) {
                        return announcement
                    } else {
                        print("   ⚠️ Failed to parse announcement from record")
                        return nil
                    }
                } catch {
                    print("   ❌ Error getting record: \(error)")
                    return nil
                }
            }

            print("✅ Successfully parsed \(items.count) announcements")
            self.announcements = items
        } catch {
            print("❌ CloudKit query error: \(error)")
            errorMessage = "Failed to fetch announcements: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Sports Events

    func fetchUpcomingSportsEvents(limit: Int = 20) async {
        isLoading = true
        errorMessage = nil

        let now = Date()
        let windowStart = now.addingTimeInterval(-24 * 60 * 60)
        let predicate = NSPredicate(
            format: "eventDate >= %@ AND status != %@",
            windowStart as NSDate, SportsEvent.EventStatus.cancelled.rawValue
        )

        let query = CKQuery(recordType: "SportsEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "eventDate", ascending: true)]

        do {
            let results = try await publicDatabase.records(matching: query)
            let items = results.matchResults.compactMap { try? $0.1.get() }.compactMap { SportsEvent(record: $0) }
            self.sportsEvents = Array(items.prefix(limit))
        } catch {
            errorMessage = "Failed to fetch sports events: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func fetchRecentSportsResults(limit: Int = 10) async {
        isLoading = true
        errorMessage = nil

        let predicate = NSPredicate(format: "status == %@", SportsEvent.EventStatus.completed.rawValue)
        let query = CKQuery(recordType: "SportsEvent", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "eventDate", ascending: false)]

        do {
            let results = try await publicDatabase.records(matching: query)
            let items = results.matchResults.compactMap { try? $0.1.get() }.compactMap { SportsEvent(record: $0) }
            self.sportsEvents = Array(items.prefix(limit))
        } catch {
            errorMessage = "Failed to fetch sports results: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Sports Teams

    func fetchActiveTeams(for season: SportsEvent.Season? = nil) async {
        isLoading = true
        errorMessage = nil

        var predicates: [NSPredicate] = [NSPredicate(format: "isActive == 1")]

        if let season = season {
            predicates.append(NSPredicate(format: "season == %@", season.rawValue))
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let query = CKQuery(recordType: "SportsTeam", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "sport", ascending: true)]

        do {
            let results = try await publicDatabase.records(matching: query)
            let items = results.matchResults.compactMap { try? $0.1.get() }.compactMap { SportsTeam(record: $0) }
            self.sportsTeams = items
        } catch {
            errorMessage = "Failed to fetch teams: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Special Schedules

    func fetchSpecialSchedule(for date: Date) async -> SpecialSchedule? {
        let preferences = UserPreferences.shared
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Check cache first
        if let cached = preferences.getCachedSpecialSchedule(for: startOfDay) {
            print("✅ Using cached special schedule for \(startOfDay): \(cached.title)")
            return cached
        }

        // Not in cache, fetch from CloudKit
        print("📡 Fetching special schedule from CloudKit for \(startOfDay)")

        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND isActive == 1",
            startOfDay as NSDate, endOfDay as NSDate
        )

        let query = CKQuery(recordType: "SpecialSchedule", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            if let firstResult = results.matchResults.first,
               let record = try? firstResult.1.get(),
               let schedule = SpecialSchedule(record: record) {
                print("📅 Found special schedule for \(date): \(schedule.title)")
                // Cache it
                preferences.cacheSpecialSchedule(schedule, for: startOfDay)
                return schedule
            }
        } catch {
            print("❌ Failed to fetch special schedule: \(error)")
        }

        return nil
    }

    // Prefetch special schedules for the next week
    func prefetchUpcomingSpecialSchedules() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Fetch schedules for next 7 days
        guard let weekFromNow = calendar.date(byAdding: .day, value: 7, to: today) else {
            return
        }

        let predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND isActive == 1",
            today as NSDate,
            weekFromNow as NSDate
        )

        let query = CKQuery(recordType: "SpecialSchedule", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            let results = try await publicDatabase.records(matching: query)
            let preferences = UserPreferences.shared

            var count = 0
            for result in results.matchResults {
                if let record = try? result.1.get(),
                   let schedule = SpecialSchedule(record: record) {
                    if let scheduleDate = schedule.date {
                        let dateKey = calendar.startOfDay(for: scheduleDate)
                        preferences.cacheSpecialSchedule(schedule, for: dateKey)
                        count += 1
                    }
                }
            }

            print("✅ Prefetched \(count) special schedules for the upcoming week")

            // Clean up old cached schedules
            preferences.cleanOldCachedSchedules()
        } catch {
            print("❌ Failed to prefetch special schedules: \(error)")
        }
    }

    // MARK: - User Preferences

    func fetchUserPreferences(userId: String) async -> (notificationsNextClass: Bool, notificationsSportsUpdates: Bool, notificationsAnnouncements: Bool)? {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserPreferences", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            if let firstResult = results.matchResults.first,
               let record = try? firstResult.1.get() {
                let nextClass = (record["notificationsNextClass"] as? Int64 ?? 1) == 1
                let sports = (record["notificationsSportsUpdates"] as? Int64 ?? 1) == 1
                let announcements = (record["notificationsAnnouncements"] as? Int64 ?? 1) == 1

                print("✅ Loaded user preferences from CloudKit")
                return (nextClass, sports, announcements)
            }
        } catch {
            print("❌ Failed to fetch user preferences: \(error)")
        }

        return nil
    }

    func saveUserPreferences(userId: String, notificationsNextClass: Bool, notificationsSportsUpdates: Bool, notificationsAnnouncements: Bool) async {
        // Check if preferences already exist
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserPreferences", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)

            let record: CKRecord
            if let firstResult = results.matchResults.first,
               let existingRecord = try? firstResult.1.get() {
                // Update existing record
                record = existingRecord
                print("📝 Updating existing user preferences in CloudKit")
            } else {
                // Create new record
                record = CKRecord(recordType: "UserPreferences")
                record["userId"] = userId as CKRecordValue
                print("📝 Creating new user preferences in CloudKit")
            }

            record["notificationsNextClass"] = (notificationsNextClass ? 1 : 0) as CKRecordValue
            record["notificationsSportsUpdates"] = (notificationsSportsUpdates ? 1 : 0) as CKRecordValue
            record["notificationsAnnouncements"] = (notificationsAnnouncements ? 1 : 0) as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue

            try await publicDatabase.save(record)
            print("✅ Saved user preferences to CloudKit")
        } catch {
            print("❌ Failed to save user preferences: \(error)")
        }
    }

    // MARK: - Device Token Management

    func saveDeviceToken(token: String, userId: String) async {
        // Check if token already exists for this user
        let predicate = NSPredicate(format: "userId == %@ AND deviceToken == %@", userId, token)
        let query = CKQuery(recordType: "DeviceToken", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)

            // If token already exists, just update timestamp
            if let firstResult = results.matchResults.first,
               let existingRecord = try? firstResult.1.get() {
                existingRecord["lastUpdated"] = Date() as CKRecordValue
                try await publicDatabase.save(existingRecord)
                print("✅ Updated existing device token timestamp")
                return
            }

            // Create new device token record
            let record = CKRecord(recordType: "DeviceToken")
            record["userId"] = userId as CKRecordValue
            record["deviceToken"] = token as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
            record["lastUpdated"] = Date() as CKRecordValue
            record["isActive"] = 1 as CKRecordValue

            try await publicDatabase.save(record)
            print("✅ Saved device token to CloudKit")
        } catch {
            print("❌ Failed to save device token: \(error)")
        }
    }

    func removeDeviceToken(token: String, userId: String) async {
        // Mark device token as inactive (for uninstalls or sign-outs)
        let predicate = NSPredicate(format: "userId == %@ AND deviceToken == %@", userId, token)
        let query = CKQuery(recordType: "DeviceToken", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            if let firstResult = results.matchResults.first,
               let record = try? firstResult.1.get() {
                record["isActive"] = 0 as CKRecordValue
                record["lastUpdated"] = Date() as CKRecordValue
                try await publicDatabase.save(record)
                print("✅ Marked device token as inactive")
            }
        } catch {
            print("❌ Failed to remove device token: \(error)")
        }
    }

    // MARK: - Helper Methods

    func refreshAllData() async {
        await fetchActiveAnnouncements()
        await fetchMenuItems(for: Date())
        await fetchUpcomingSportsEvents()
    }
}
