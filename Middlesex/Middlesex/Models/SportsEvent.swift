//
//  SportsEvent.swift
//  Middlesex
//
//  CloudKit models for sports events and teams
//

import Foundation
import CloudKit

struct SportsEvent: Identifiable, Hashable {
    let id: String
    let sport: Sport
    let eventType: EventType
    let opponent: String
    let eventDate: Date
    let location: String
    let isHome: Bool
    let middlesexScore: Int
    let opponentScore: Int
    let status: EventStatus
    let season: Season
    let year: Int
    let notes: String
    let createdAt: Date
    let updatedAt: Date

    enum Sport: String, CaseIterable {
        case football = "Football"
        case soccer = "Soccer"
        case basketball = "Basketball"
        case baseball = "Baseball"
        case softball = "Softball"
        case lacrosse = "Lacrosse"
        case hockey = "Hockey"
        case volleyball = "Volleyball"
        case tennis = "Tennis"
        case crossCountry = "Cross Country"
        case track = "Track & Field"
        case swimming = "Swimming"

        var icon: String {
            switch self {
            case .football: return "football.fill"
            case .soccer: return "soccerball"
            case .basketball: return "basketball.fill"
            case .baseball: return "baseball.fill"
            case .hockey: return "hockey.puck.fill"
            case .volleyball: return "volleyball.fill"
            case .tennis: return "tennisball.fill"
            default: return "figure.run"
            }
        }
    }

    enum EventType: String, CaseIterable {
        case game = "game"
        case practice = "practice"
        case tournament = "tournament"

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum EventStatus: String, CaseIterable {
        case scheduled = "scheduled"
        case inProgress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"

        var displayName: String {
            switch self {
            case .scheduled: return "Scheduled"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .cancelled: return "Cancelled"
            }
        }
    }

    enum Season: String, CaseIterable {
        case fall = "Fall"
        case winter = "Winter"
        case spring = "Spring"

        var displayName: String {
            rawValue
        }
    }

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let sportString = record["sport"] as? String,
              let sport = Sport(rawValue: sportString),
              let eventTypeString = record["eventType"] as? String,
              let eventType = EventType(rawValue: eventTypeString),
              let opponent = record["opponent"] as? String,
              let eventDate = record["eventDate"] as? Date,
              let location = record["location"] as? String,
              let statusString = record["status"] as? String,
              let status = EventStatus(rawValue: statusString),
              let seasonString = record["season"] as? String,
              let season = Season(rawValue: seasonString),
              let year = record["year"] as? Int64,
              let notes = record["notes"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            return nil
        }

        self.id = id
        self.sport = sport
        self.eventType = eventType
        self.opponent = opponent
        self.eventDate = eventDate
        self.location = location
        self.isHome = (record["isHome"] as? Int64 ?? 0) == 1
        self.middlesexScore = Int(record["middlesexScore"] as? Int64 ?? -1)
        self.opponentScore = Int(record["opponentScore"] as? Int64 ?? -1)
        self.status = status
        self.season = season
        self.year = Int(year)
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Manual initializer
    init(id: String = UUID().uuidString,
         sport: Sport,
         eventType: EventType,
         opponent: String,
         eventDate: Date,
         location: String,
         isHome: Bool,
         middlesexScore: Int = -1,
         opponentScore: Int = -1,
         status: EventStatus = .scheduled,
         season: Season,
         year: Int,
         notes: String = "",
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.sport = sport
        self.eventType = eventType
        self.opponent = opponent
        self.eventDate = eventDate
        self.location = location
        self.isHome = isHome
        self.middlesexScore = middlesexScore
        self.opponentScore = opponentScore
        self.status = status
        self.season = season
        self.year = year
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var result: String? {
        guard status == .completed, middlesexScore >= 0, opponentScore >= 0 else {
            return nil
        }
        if middlesexScore > opponentScore {
            return "W \(middlesexScore)-\(opponentScore)"
        } else if middlesexScore < opponentScore {
            return "L \(middlesexScore)-\(opponentScore)"
        } else {
            return "T \(middlesexScore)-\(opponentScore)"
        }
    }

    // Convert to CloudKit record
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "SportsEvent")
        record["id"] = id as CKRecordValue
        record["sport"] = sport.rawValue as CKRecordValue
        record["eventType"] = eventType.rawValue as CKRecordValue
        record["opponent"] = opponent as CKRecordValue
        record["eventDate"] = eventDate as CKRecordValue
        record["location"] = location as CKRecordValue
        record["isHome"] = (isHome ? 1 : 0) as CKRecordValue
        record["middlesexScore"] = middlesexScore as CKRecordValue
        record["opponentScore"] = opponentScore as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        record["season"] = season.rawValue as CKRecordValue
        record["year"] = year as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        return record
    }
}

struct SportsTeam: Identifiable, Hashable {
    let id: String
    let sport: SportsEvent.Sport
    let teamName: String
    let season: SportsEvent.Season
    let year: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let coachName: String
    let captains: [String]
    let rosterURL: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let sportString = record["sport"] as? String,
              let sport = SportsEvent.Sport(rawValue: sportString),
              let teamName = record["teamName"] as? String,
              let seasonString = record["season"] as? String,
              let season = SportsEvent.Season(rawValue: seasonString),
              let year = record["year"] as? Int64,
              let wins = record["wins"] as? Int64,
              let losses = record["losses"] as? Int64,
              let ties = record["ties"] as? Int64,
              let coachName = record["coachName"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            return nil
        }

        self.id = id
        self.sport = sport
        self.teamName = teamName
        self.season = season
        self.year = Int(year)
        self.wins = Int(wins)
        self.losses = Int(losses)
        self.ties = Int(ties)
        self.coachName = coachName

        let captainsString = record["captains"] as? String ?? ""
        self.captains = captainsString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

        self.rosterURL = record["rosterURL"] as? String
        self.isActive = (record["isActive"] as? Int64 ?? 0) == 1
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var record: String {
        "\(wins)-\(losses)" + (ties > 0 ? "-\(ties)" : "")
    }
}
