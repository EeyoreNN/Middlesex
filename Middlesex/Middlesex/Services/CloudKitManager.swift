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
    @Published private(set) var permanentAdmins: [PermanentAdmin] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var hasLoadedPermanentAdmins = false

    private init() {
        // CloudKit container identifier matching entitlements
        container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
        publicDatabase = container.publicCloudDatabase

        // Check iCloud account status
        Task {
            await checkAccountStatus()
        }

        Task {
            await refreshPermanentAdmins()
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

    // MARK: - Admin Access

    func refreshPermanentAdmins(force: Bool = false) async {
        if hasLoadedPermanentAdmins && !force {
            await evaluateAdminAccessState()
            return
        }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "PermanentAdmin", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            var fetched: [PermanentAdmin] = []

            for result in results.matchResults {
                do {
                    let record = try result.1.get()
                    if let admin = PermanentAdmin(record: record) {
                        fetched.append(admin)
                    }
                } catch {
                    print("⚠️ Failed to parse PermanentAdmin record: \(error)")
                }
            }

            permanentAdmins = fetched
            hasLoadedPermanentAdmins = true
            await evaluateAdminAccessState()
            print("✅ Loaded \(fetched.count) permanent admins")
        } catch {
            hasLoadedPermanentAdmins = false
            print("❌ Failed to fetch permanent admins: \(error)")
            await evaluateAdminAccessState()
        }
    }

    func isPermanentAdmin(userId: String) -> Bool {
        guard !userId.isEmpty else { return false }
        return permanentAdmins.contains { $0.userId == userId }
    }

    func permanentAdminCodeAlreadyClaimed() -> Bool {
        if permanentAdmins.contains(where: { $0.sourceCode == AdminAccessConfig.permanentAdminCode }) {
            return true
        }
        return !permanentAdmins.isEmpty
    }

    func canGenerateAdminCodes(userId: String, fallbackName: String) -> Bool {
        if !userId.isEmpty,
           permanentAdmins.contains(where: { $0.userId == userId && $0.canGenerateCodes }) {
            return true
        }

        return AdminAccessConfig.legacyCodeGeneratorNames.contains(fallbackName)
    }

    func isCurrentUserPermanentAdmin() -> Bool {
        let preferences = UserPreferences.shared
        let userId = preferences.userIdentifier
        guard !userId.isEmpty else { return false }
        return isPermanentAdmin(userId: userId)
    }

    func saveAdminCode(_ adminCode: AdminCode) async throws {
        let record = adminCode.toRecord()
        _ = try await publicDatabase.save(record)
    }

    func registerPermanentAdmin(userId: String, displayName: String?, sourceCode: String) async throws {
        let record = PermanentAdmin.makeRecord(
            userId: userId,
            displayName: displayName,
            sourceCode: sourceCode
        )

        let savedRecord = try await publicDatabase.save(record)

        if let admin = PermanentAdmin(record: savedRecord) {
            permanentAdmins.removeAll { $0.recordID == admin.recordID }
            permanentAdmins.append(admin)
            hasLoadedPermanentAdmins = true
            await evaluateAdminAccessState()
            print("✅ Registered permanent admin for userId \(userId)")
        } else {
            print("⚠️ Saved permanent admin but failed to parse record")
        }
    }

    func removePermanentAdmin(_ admin: PermanentAdmin) async throws {
        try await publicDatabase.deleteRecord(withID: admin.recordID)
        permanentAdmins.removeAll { $0.recordID == admin.recordID }
        if permanentAdmins.isEmpty {
            hasLoadedPermanentAdmins = false
        }
        await evaluateAdminAccessState()
        print("🗑️ Removed permanent admin for userId \(admin.userId)")
    }

    private func evaluateAdminAccessState() async {
        let preferences = UserPreferences.shared
        let userId = preferences.userIdentifier

        guard !userId.isEmpty else {
            preferences.hasPermanentAdminAccess = false
            preferences.isAdmin = false
            return
        }

        let hasPermanentAccess = permanentAdmins.contains { $0.userId == userId && $0.canGenerateCodes }

        preferences.hasPermanentAdminAccess = hasPermanentAccess

        if hasPermanentAccess {
            preferences.isAdmin = true
            return
        }

        let hasActiveTemporary = await hasActiveTemporaryAdminCode(userId: userId)
        preferences.isAdmin = hasActiveTemporary
    }

    private func hasActiveTemporaryAdminCode(userId: String) async -> Bool {
        let predicate = NSPredicate(format: "usedBy == %@ AND isUsed == 1", userId)
        let query = CKQuery(recordType: "AdminCode", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            for result in results.matchResults {
                do {
                    let record = try result.1.get()
                    if let adminCode = AdminCode(record: record),
                       adminCode.type == .temporary,
                       !adminCode.isExpired {
                        return true
                    }
                } catch {
                    print("⚠️ Failed to parse AdminCode record during temporary check: \(error)")
                }
            }
        } catch {
            print("❌ Failed to evaluate temporary admin codes: \(error)")
        }

        return false
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

            // Filter announcements by target audience based on user's grade and name
            let userGrade = UserPreferences.shared.userGrade
            let userName = UserPreferences.shared.userName
            let filteredItems = items.filter { announcement in
                let isTargeted = announcement.isTargetedTo(userGrade: userGrade, userName: userName)
                if !isTargeted {
                    print("🎯 Filtering out '\(announcement.title)' - not targeted to \(userGrade)/\(userName)")
                }
                return isTargeted
            }

            print("✅ Successfully parsed \(items.count) announcements, \(filteredItems.count) targeted to user")
            self.announcements = filteredItems
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

    // MARK: - User Data Sync

    struct UserData {
        let userName: String
        let userGrade: String
        let prefersCelsius: Bool
        let notificationsNextClass: Bool
        let notificationsSportsUpdates: Bool
        let notificationsAnnouncements: Bool
    }

    struct UserSchedules {
        let redWeek: [Int: UserClass]
        let whiteWeek: [Int: UserClass]
    }

    func fetchUserData(userId: String) async -> UserData? {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserPreferences", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            if let firstResult = results.matchResults.first,
               let record = try? firstResult.1.get() {
                let userName = record["userName"] as? String ?? ""
                let userGrade = record["userGrade"] as? String ?? ""
                let prefersCelsius = (record["prefersCelsius"] as? Int64 ?? 0) == 1
                let nextClass = (record["notificationsNextClass"] as? Int64 ?? 1) == 1
                let sports = (record["notificationsSportsUpdates"] as? Int64 ?? 1) == 1
                let announcements = (record["notificationsAnnouncements"] as? Int64 ?? 1) == 1

                print("✅ Loaded user data from CloudKit")
                return UserData(
                    userName: userName,
                    userGrade: userGrade,
                    prefersCelsius: prefersCelsius,
                    notificationsNextClass: nextClass,
                    notificationsSportsUpdates: sports,
                    notificationsAnnouncements: announcements
                )
            }
        } catch {
            print("❌ Failed to fetch user data: \(error)")
        }

        return nil
    }

    func saveUserData(userId: String, userName: String, userGrade: String, prefersCelsius: Bool, notificationsNextClass: Bool, notificationsSportsUpdates: Bool, notificationsAnnouncements: Bool) async {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserPreferences", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)

            let record: CKRecord
            if let firstResult = results.matchResults.first,
               let existingRecord = try? firstResult.1.get() {
                record = existingRecord
                print("📝 Updating existing user preferences in CloudKit")
            } else {
                record = CKRecord(recordType: "UserPreferences")
                record["userId"] = userId as CKRecordValue
                print("📝 Creating new user preferences in CloudKit")
            }

            record["userName"] = userName as CKRecordValue
            record["userGrade"] = userGrade as CKRecordValue
            record["prefersCelsius"] = (prefersCelsius ? 1 : 0) as CKRecordValue
            record["notificationsNextClass"] = (notificationsNextClass ? 1 : 0) as CKRecordValue
            record["notificationsSportsUpdates"] = (notificationsSportsUpdates ? 1 : 0) as CKRecordValue
            record["notificationsAnnouncements"] = (notificationsAnnouncements ? 1 : 0) as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue

            try await publicDatabase.save(record)
            print("✅ Saved user data to CloudKit")
        } catch {
            print("❌ Failed to save user data: \(error)")
        }
    }

    func fetchUserSchedules(userId: String) async -> UserSchedules? {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserSchedule", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)
            if let firstResult = results.matchResults.first,
               let record = try? firstResult.1.get() {
                let redWeekData = record["redWeek"] as? Data
                let whiteWeekData = record["whiteWeek"] as? Data

                let redWeek = try redWeekData.flatMap { try JSONDecoder().decode([Int: UserClass].self, from: $0) } ?? [:]
                let whiteWeek = try whiteWeekData.flatMap { try JSONDecoder().decode([Int: UserClass].self, from: $0) } ?? [:]

                print("✅ Loaded user schedules from CloudKit")
                return UserSchedules(redWeek: redWeek, whiteWeek: whiteWeek)
            }
        } catch {
            print("❌ Failed to fetch user schedules: \(error)")
        }

        return nil
    }

    func saveUserSchedules(userId: String, redWeek: [Int: UserClass], whiteWeek: [Int: UserClass]) async {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserSchedule", predicate: predicate)

        do {
            let results = try await publicDatabase.records(matching: query)

            let record: CKRecord
            if let firstResult = results.matchResults.first,
               let existingRecord = try? firstResult.1.get() {
                record = existingRecord
                print("📝 Updating existing user schedule in CloudKit")
            } else {
                record = CKRecord(recordType: "UserSchedule")
                record["userId"] = userId as CKRecordValue
                print("📝 Creating new user schedule in CloudKit")
            }

            let redWeekData = try? JSONEncoder().encode(redWeek)
            let whiteWeekData = try? JSONEncoder().encode(whiteWeek)

            if let redData = redWeekData {
                record["redWeek"] = redData as CKRecordValue
            }
            if let whiteData = whiteWeekData {
                record["whiteWeek"] = whiteData as CKRecordValue
            }
            record["updatedAt"] = Date() as CKRecordValue

            try await publicDatabase.save(record)
            print("✅ Saved user schedules to CloudKit")
        } catch {
            print("❌ Failed to save user schedules: \(error)")
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
