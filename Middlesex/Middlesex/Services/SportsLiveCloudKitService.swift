//
//  SportsLiveCloudKitService.swift
//  Middlesex
//
//  CloudKit helpers for sports Live Activity features.
//

import Foundation
import CloudKit

@available(iOS 16.2, *)
@MainActor
final class SportsLiveCloudKitService {
    enum ServiceError: Error {
        case reporterAlreadyClaimed(by: String)
        case recordNotFound
    }

    static let shared = SportsLiveCloudKitService()

    private let container: CKContainer
    private let database: CKDatabase

    private init() {
        container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
        database = container.publicCloudDatabase
    }

    // MARK: - Reporter Claims

    func fetchActiveClaim(for eventId: String, asOf date: Date = Date()) async throws -> SportsReporterClaim? {
        let predicate = NSPredicate(
            format: "eventId == %@ AND status == %@ AND expiresAt > %@",
            eventId, SportsReporterClaim.Status.active.rawValue, date as NSDate
        )

        let query = CKQuery(recordType: "SportsReporterClaim", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "claimedAt", ascending: false)]

        let result = try await database.records(matching: query, resultsLimit: 1)
        guard let match = result.matchResults.first else { return nil }
        guard case let .success(record) = match.1 else { return nil }
        return SportsReporterClaim(record: record)
    }

    func claimReporter(
        eventId: String,
        reporterId: String,
        reporterName: String,
        expiresAt: Date
    ) async throws -> SportsReporterClaim {
        if let existing = try await fetchActiveClaim(for: eventId) {
            throw ServiceError.reporterAlreadyClaimed(by: existing.reporterName)
        }

        let claim = SportsReporterClaim(
            id: eventId, // enforce one active claim per event
            eventId: eventId,
            reporterId: reporterId,
            reporterName: reporterName,
            claimedAt: Date(),
            expiresAt: expiresAt,
            status: .active
        )

        let record = claim.toRecord()
        _ = try await database.save(record)
        return claim
    }

    func releaseReporter(eventId: String) async throws {
        let recordID = CKRecord.ID(recordName: eventId)
        let record = try await database.record(for: recordID)
        record["status"] = SportsReporterClaim.Status.released.rawValue as CKRecordValue
        _ = try await database.save(record)
    }

    // MARK: - Live Updates

    func fetchLatestUpdate(for eventId: String) async throws -> SportsLiveUpdate? {
        let predicate = NSPredicate(format: "eventId == %@", eventId)
        let query = CKQuery(recordType: "SportsLiveUpdate", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let result = try await database.records(matching: query, resultsLimit: 1)
        guard let match = result.matchResults.first else { return nil }
        guard case let .success(record) = match.1 else { return nil }
        return SportsLiveUpdate(record: record)
    }

    func saveUpdate(_ update: SportsLiveUpdate) async throws {
        let record = update.toRecord()
        _ = try await database.save(record)
    }

    // MARK: - Live Activity Subscriptions

    func registerSubscription(_ subscription: SportsLiveSubscription) async throws {
        let record = subscription.toRecord()
        _ = try await database.save(record)
    }

    func removeSubscription(eventId: String, userId: String) async throws {
        let recordID = CKRecord.ID(recordName: "\(eventId)-\(userId)")
        do {
            try await database.deleteRecord(withID: recordID)
        } catch {
            // Ignore if not found
        }
    }
}
