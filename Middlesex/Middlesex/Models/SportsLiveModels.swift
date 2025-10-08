//
//  SportsLiveModels.swift
//  Middlesex
//
//  CloudKit-backed models powering sports Live Activities.
//

import Foundation
import CloudKit

@available(iOS 16.2, *)
struct SportsLiveUpdate: Identifiable, Hashable {
    let id: String
    let eventId: String
    let sport: SportsActivityAttributes.SportType
    let state: SportsActivityAttributes.ContentState
    let summary: String?
    let reporterId: String?
    let reporterName: String?
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String,
        sport: SportsActivityAttributes.SportType,
        state: SportsActivityAttributes.ContentState,
        summary: String?,
        reporterId: String?,
        reporterName: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.sport = sport
        self.state = state
        self.summary = summary
        self.reporterId = reporterId
        self.reporterName = reporterName
        self.createdAt = createdAt
    }

    init?(record: CKRecord) {
        guard let eventId = record["eventId"] as? String,
              let sportRaw = record["sport"] as? String,
              let sport = SportsActivityAttributes.SportType(rawValue: sportRaw),
              let statusRaw = record["status"] as? String,
              let status = SportsActivityAttributes.GameStatus(rawValue: statusRaw),
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        let homeScore = record["homeScore"] as? Int
        let awayScore = record["awayScore"] as? Int
        let periodLabel = record["periodLabel"] as? String
        let clockRemaining = record["clockRemaining"] as? Double
        let clockLastUpdated = record["clockLastUpdated"] as? Date
        let possessionRaw = record["possession"] as? String
        let possession = possessionRaw.flatMap { SportsActivityAttributes.TeamSide(rawValue: $0) }
        let lastEventSummary = record["lastEventSummary"] as? String
        let lastEventDetail = record["lastEventDetail"] as? String
        let highlightIcon = record["highlightIcon"] as? String
        let topFinishersJSON = record["topFinishersJSON"] as? String
        let teamResultsJSON = record["teamResultsJSON"] as? String

        let topFinishers = (try? JSONDecoder().decode([SportsActivityAttributes.Finisher].self, from: Data((topFinishersJSON ?? "[]").utf8))) ?? []
        let teamResults = (try? JSONDecoder().decode([SportsActivityAttributes.TeamResult].self, from: Data((teamResultsJSON ?? "[]").utf8))) ?? []

        let updatedAt = record["updatedAt"] as? Date ?? createdAt

        let state = SportsActivityAttributes.ContentState(
            status: status,
            homeScore: homeScore,
            awayScore: awayScore,
            periodLabel: periodLabel,
            clockRemaining: clockRemaining,
            clockLastUpdated: clockLastUpdated,
            possession: possession,
            lastEventSummary: lastEventSummary,
            lastEventDetail: lastEventDetail,
            highlightIcon: highlightIcon,
            topFinishers: topFinishers,
            teamResults: teamResults,
            updatedAt: updatedAt,
            reporterName: record["reporterName"] as? String
        )

        self.id = record.recordID.recordName
        self.eventId = eventId
        self.sport = sport
        self.state = state
        self.summary = record["summary"] as? String
        self.reporterId = record["reporterId"] as? String
        self.reporterName = record["reporterName"] as? String
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "SportsLiveUpdate", recordID: recordID)
        record["id"] = id as CKRecordValue
        record["eventId"] = eventId as CKRecordValue
        record["sport"] = sport.rawValue as CKRecordValue
        record["status"] = state.status.rawValue as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = state.updatedAt as CKRecordValue

        if let summary = summary {
            record["summary"] = summary as CKRecordValue
        }

        if let reporterId = reporterId {
            record["reporterId"] = reporterId as CKRecordValue
        }

        if let reporterName = reporterName ?? state.reporterName {
            record["reporterName"] = reporterName as CKRecordValue
        }

        if let homeScore = state.homeScore {
            record["homeScore"] = homeScore as CKRecordValue
        }
        if let awayScore = state.awayScore {
            record["awayScore"] = awayScore as CKRecordValue
        }
        if let periodLabel = state.periodLabel {
            record["periodLabel"] = periodLabel as CKRecordValue
        }
        if let clockRemaining = state.clockRemaining {
            record["clockRemaining"] = clockRemaining as CKRecordValue
        }
        if let clockLastUpdated = state.clockLastUpdated {
            record["clockLastUpdated"] = clockLastUpdated as CKRecordValue
        }
        if let possession = state.possession {
            record["possession"] = possession.rawValue as CKRecordValue
        }
        if let lastEventSummary = state.lastEventSummary {
            record["lastEventSummary"] = lastEventSummary as CKRecordValue
        }
        if let lastEventDetail = state.lastEventDetail {
            record["lastEventDetail"] = lastEventDetail as CKRecordValue
        }
        if let highlightIcon = state.highlightIcon {
            record["highlightIcon"] = highlightIcon as CKRecordValue
        }

        if !state.topFinishers.isEmpty {
            let encoded = try? JSONEncoder().encode(state.topFinishers)
            record["topFinishersJSON"] = String(data: encoded ?? Data("[]".utf8), encoding: .utf8) as CKRecordValue?
        }

        if !state.teamResults.isEmpty {
            let encoded = try? JSONEncoder().encode(state.teamResults)
            record["teamResultsJSON"] = String(data: encoded ?? Data("[]".utf8), encoding: .utf8) as CKRecordValue?
        }

        return record
    }
}

struct SportsReporterClaim: Identifiable, Hashable {
    enum Status: String {
        case pending
        case active
        case released
    }

    let id: String
    let eventId: String
    let reporterId: String
    let reporterName: String
    let claimedAt: Date
    let expiresAt: Date
    let status: Status

    init(
        id: String = UUID().uuidString,
        eventId: String,
        reporterId: String,
        reporterName: String,
        claimedAt: Date = Date(),
        expiresAt: Date,
        status: Status = .active
    ) {
        self.id = id
        self.eventId = eventId
        self.reporterId = reporterId
        self.reporterName = reporterName
        self.claimedAt = claimedAt
        self.expiresAt = expiresAt
        self.status = status
    }

    init?(record: CKRecord) {
        guard let eventId = record["eventId"] as? String,
              let reporterId = record["reporterId"] as? String,
              let reporterName = record["reporterName"] as? String,
              let claimedAt = record["claimedAt"] as? Date,
              let expiresAt = record["expiresAt"] as? Date,
              let statusRaw = record["status"] as? String,
              let status = Status(rawValue: statusRaw) else {
            return nil
        }

        self.id = record.recordID.recordName
        self.eventId = eventId
        self.reporterId = reporterId
        self.reporterName = reporterName
        self.claimedAt = claimedAt
        self.expiresAt = expiresAt
        self.status = status
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "SportsReporterClaim", recordID: recordID)
        record["id"] = id as CKRecordValue
        record["eventId"] = eventId as CKRecordValue
        record["reporterId"] = reporterId as CKRecordValue
        record["reporterName"] = reporterName as CKRecordValue
        record["claimedAt"] = claimedAt as CKRecordValue
        record["expiresAt"] = expiresAt as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        return record
    }
}

@available(iOS 16.2, *)
struct SportsLiveSubscription: Identifiable, Hashable {
    let id: String
    let eventId: String
    let userId: String
    let sport: SportsActivityAttributes.SportType
    let pushToken: Data
    let deviceName: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        eventId: String,
        userId: String,
        sport: SportsActivityAttributes.SportType,
        pushToken: Data,
        deviceName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.userId = userId
        self.sport = sport
        self.pushToken = pushToken
        self.deviceName = deviceName
        self.createdAt = createdAt
    }

    init?(record: CKRecord) {
        guard let eventId = record["eventId"] as? String,
              let userId = record["userId"] as? String,
              let sportRaw = record["sport"] as? String,
              let sport = SportsActivityAttributes.SportType(rawValue: sportRaw),
              let tokenString = record["pushToken"] as? String,
              let tokenData = Data(base64Encoded: tokenString),
              let deviceName = record["deviceName"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        self.id = record.recordID.recordName
        self.eventId = eventId
        self.userId = userId
        self.sport = sport
        self.pushToken = tokenData
        self.deviceName = deviceName
        self.createdAt = createdAt
    }

    func toRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "SportsLiveSubscription", recordID: recordID)
        record["id"] = id as CKRecordValue
        record["eventId"] = eventId as CKRecordValue
        record["userId"] = userId as CKRecordValue
        record["sport"] = sport.rawValue as CKRecordValue
        record["deviceName"] = deviceName as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["pushToken"] = pushToken.base64EncodedString() as CKRecordValue
        return record
    }
}
