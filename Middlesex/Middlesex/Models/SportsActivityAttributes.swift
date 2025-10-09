//
//  SportsActivityAttributes.swift
//  Middlesex
//
//  Live Activity attributes and shared models for sports events.
//

import Foundation
import ActivityKit
import SwiftUI

@available(iOS 16.2, *)
struct SportsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: GameStatus
        var homeScore: Int?
        var awayScore: Int?
        var periodLabel: String?
        var clockRemaining: TimeInterval?
        var clockLastUpdated: Date?
        var possession: TeamSide?
        var lastEventSummary: String?
        var lastEventDetail: String?
        var highlightIcon: String?
        var topFinishers: [Finisher]
        var teamResults: [TeamResult]
        var updatedAt: Date
        var reporterName: String?

        init(
            status: GameStatus,
            homeScore: Int? = nil,
            awayScore: Int? = nil,
            periodLabel: String? = nil,
            clockRemaining: TimeInterval? = nil,
            clockLastUpdated: Date? = nil,
            possession: TeamSide? = nil,
            lastEventSummary: String? = nil,
            lastEventDetail: String? = nil,
            highlightIcon: String? = nil,
            topFinishers: [Finisher] = [],
            teamResults: [TeamResult] = [],
            updatedAt: Date = Date(),
            reporterName: String? = nil
        ) {
            self.status = status
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.periodLabel = periodLabel
            self.clockRemaining = clockRemaining
            self.clockLastUpdated = clockLastUpdated
            self.possession = possession
            self.lastEventSummary = lastEventSummary
            self.lastEventDetail = lastEventDetail
            self.highlightIcon = highlightIcon
            self.topFinishers = topFinishers
            self.teamResults = teamResults
            self.updatedAt = updatedAt
            self.reporterName = reporterName
        }
    }

    enum SportType: String, Codable, CaseIterable, Hashable {
        case soccer
        case football
        case crossCountry

        var displayName: String {
            switch self {
            case .soccer: return "Soccer"
            case .football: return "Football"
        case .crossCountry: return "Cross Country"
        }
    }

    var themeColor: Color {
        switch self {
        case .soccer: return Color(red: 0.12, green: 0.62, blue: 0.36)
        case .football: return Color(red: 0.65, green: 0.22, blue: 0.17)
        case .crossCountry: return Color(red: 0.18, green: 0.34, blue: 0.72)
        }
    }

    var iconName: String {
        switch self {
        case .soccer: return "soccerball"
        case .football: return "sportscourt"
        case .crossCountry: return "figure.run"
        }
    }
}

    enum GameStatus: String, Codable, Hashable, CaseIterable {
        case upcoming
        case live
        case final

        var displayName: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .live: return "Live"
            case .final: return "Final"
            }
        }
    }

    enum TeamSide: String, Codable, Hashable {
        case middlesex
        case opponent
    }

    struct Finisher: Codable, Hashable {
        var position: Int
        var name: String
        var school: String
        var finishTime: String

        init(position: Int, name: String, school: String, finishTime: String) {
            self.position = position
            self.name = name
            self.school = school
            self.finishTime = finishTime
        }
    }

    struct TeamResult: Codable, Hashable {
        var position: Int
        var school: String
        var points: Int

        init(position: Int, school: String, points: Int) {
            self.position = position
            self.school = school
            self.points = points
        }
    }

    // Fixed metadata for the live activity
    var sportType: SportType
    var eventId: String
    var eventName: String
    var opponent: String
    var location: String
    var startDate: Date
    var homeTeamName: String
    var opponentTeamName: String
    var reporterName: String?

    init(
        sportType: SportType,
        eventId: String,
        eventName: String,
        opponent: String,
        location: String,
        startDate: Date,
        homeTeamName: String = "Middlesex",
        opponentTeamName: String? = nil,
        reporterName: String? = nil
    ) {
        self.sportType = sportType
        self.eventId = eventId
        self.eventName = eventName
        self.opponent = opponent
        self.location = location
        self.startDate = startDate
        self.homeTeamName = homeTeamName
        self.opponentTeamName = opponentTeamName ?? opponent
        self.reporterName = reporterName
    }
}

@available(iOS 16.2, *)
extension SportsActivityAttributes.ContentState {
    func currentClockRemaining(at date: Date = Date()) -> TimeInterval? {
        guard let remaining = clockRemaining else { return nil }

        guard let lastUpdated = clockLastUpdated else {
            return max(remaining, 0)
        }

        let elapsed = date.timeIntervalSince(lastUpdated)
        if elapsed <= 0 {
            return max(remaining, 0)
        }

        // If game is live, calculate current remaining time
        if status == .live {
            let calculatedRemaining = remaining - elapsed
            return max(calculatedRemaining, 0)
        } else {
            return max(remaining, 0)
        }
    }

    func formattedClock(at date: Date = Date()) -> String? {
        guard let remaining = currentClockRemaining(at: date) else { return nil }
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}
