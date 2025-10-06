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
        // Replace with your actual CloudKit container identifier
        container = CKContainer(identifier: "iCloud.com.middlesex.app")
        publicDatabase = container.publicCloudDatabase
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
        let predicate = NSPredicate(
            format: "isActive == 1 AND publishDate <= %@ AND expiryDate >= %@",
            now as NSDate, now as NSDate
        )

        let query = CKQuery(recordType: "Announcement", predicate: predicate)
        query.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "publishDate", ascending: false)
        ]

        do {
            let results = try await publicDatabase.records(matching: query)
            let items = results.matchResults.compactMap { try? $0.1.get() }.compactMap { Announcement(record: $0) }
            self.announcements = items
        } catch {
            errorMessage = "Failed to fetch announcements: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Sports Events

    func fetchUpcomingSportsEvents(limit: Int = 20) async {
        isLoading = true
        errorMessage = nil

        let now = Date()
        let predicate = NSPredicate(
            format: "eventDate >= %@ AND status != %@",
            now as NSDate, SportsEvent.EventStatus.cancelled.rawValue
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

    // MARK: - Helper Methods

    func refreshAllData() async {
        await fetchActiveAnnouncements()
        await fetchMenuItems(for: Date())
        await fetchUpcomingSportsEvents()
    }
}
