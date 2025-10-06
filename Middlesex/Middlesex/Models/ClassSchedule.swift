//
//  ClassSchedule.swift
//  Middlesex
//
//  CloudKit model for class schedules with Red/White week system
//

import Foundation
import CloudKit

struct ClassSchedule: Identifiable, Hashable {
    let id: String
    let weekType: WeekType
    let period: Int
    let className: String
    let teacher: String
    let room: String
    let startTime: String
    let endTime: String
    let color: String
    let isActive: Bool
    let semester: Semester
    let year: Int
    let createdAt: Date

    enum WeekType: String, CaseIterable {
        case red = "Red"
        case white = "White"

        var displayName: String {
            rawValue
        }
    }

    enum Semester: String, CaseIterable {
        case fall = "Fall"
        case spring = "Spring"

        var displayName: String {
            rawValue
        }
    }

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let weekTypeString = record["weekType"] as? String,
              let weekType = WeekType(rawValue: weekTypeString),
              let period = record["period"] as? Int64,
              let className = record["className"] as? String,
              let teacher = record["teacher"] as? String,
              let room = record["room"] as? String,
              let startTime = record["startTime"] as? String,
              let endTime = record["endTime"] as? String,
              let color = record["color"] as? String,
              let semesterString = record["semester"] as? String,
              let semester = Semester(rawValue: semesterString),
              let year = record["year"] as? Int64,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        self.id = id
        self.weekType = weekType
        self.period = Int(period)
        self.className = className
        self.teacher = teacher
        self.room = room
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.isActive = (record["isActive"] as? Int64 ?? 0) == 1
        self.semester = semester
        self.year = Int(year)
        self.createdAt = createdAt
    }

    // Manual initializer
    init(id: String = UUID().uuidString,
         weekType: WeekType,
         period: Int,
         className: String,
         teacher: String,
         room: String,
         startTime: String,
         endTime: String,
         color: String = "#C8102E",
         isActive: Bool = true,
         semester: Semester,
         year: Int,
         createdAt: Date = Date()) {
        self.id = id
        self.weekType = weekType
        self.period = period
        self.className = className
        self.teacher = teacher
        self.room = room
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.isActive = isActive
        self.semester = semester
        self.year = year
        self.createdAt = createdAt
    }
}

// Period times configuration (stored locally or in CloudKit)
struct PeriodTime: Identifiable, Codable, Hashable {
    let id: String
    let period: Int
    let startTime: String
    let endTime: String

    init(id: String = UUID().uuidString, period: Int, startTime: String, endTime: String) {
        self.id = id
        self.period = period
        self.startTime = startTime
        self.endTime = endTime
    }

    // Default Middlesex schedule - 7 blocks (A-G map to periods 1-7)
    // Times vary by day, these are approximate
    static let defaultSchedule = [
        PeriodTime(period: 1, startTime: "A Block", endTime: "~40 min"),
        PeriodTime(period: 2, startTime: "B Block", endTime: "~40 min"),
        PeriodTime(period: 3, startTime: "C Block", endTime: "~40 min"),
        PeriodTime(period: 4, startTime: "D Block", endTime: "~40 min"),
        PeriodTime(period: 5, startTime: "E Block", endTime: "~40 min"),
        PeriodTime(period: 6, startTime: "F Block", endTime: "~40 min"),
        PeriodTime(period: 7, startTime: "G Block", endTime: "~40 min")
    ]
}
