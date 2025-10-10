//
//  DailySchedule.swift
//  Middlesex
//
//  Daily schedule with actual times for each block
//
//  X Block Schedule by Block:
//  Red Week:
//    A: Monday, Thursday
//    B: Wednesday, Friday
//    C: Tuesday, Thursday
//    D: Monday, Saturday
//    E: Monday, Thursday
//    F: Wednesday, Friday
//    G: Tuesday, Saturday
//
//  White Week:
//    A: Monday, Thursday
//    B: Friday, Saturday
//    C: Tuesday, Thursday
//    D: Monday, Wednesday
//    E: Monday, Thursday
//    F: Friday, Saturday
//    G: Tuesday, Wednesday
//
//  Note: Individual classes may vary from the standard block schedule
//  Example: Elements of Novels and Stories (F block) uses X blocks:
//    - Red Week: Friday only (not Wednesday)
//    - White Week: Friday and Saturday
//

import Foundation

struct BlockTime: Identifiable, Codable {
    let id: UUID
    let block: String // "A", "Ax", "F", etc.
    let startTime: String
    let endTime: String

    init(block: String, startTime: String, endTime: String) {
        self.id = UUID()
        self.block = block
        self.startTime = startTime
        self.endTime = endTime
    }

    // Parse time string like "8:00" or "1:20" to Date
    // Note: Times after 12:55 use 12-hour format and are PM (e.g., "1:20" = 1:20 PM, "2:05" = 2:05 PM)
    func parseTime(_ timeString: String, on date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              var hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        // Convert 12-hour PM times to 24-hour format
        // Times from 1-11 with minutes >= 0 after noon are PM
        // If hour is 1-11 and we're clearly in afternoon (past noon), add 12
        if hour >= 1 && hour <= 11 {
            // Check if this looks like an afternoon time based on context
            // Times like "1:20", "2:05", "2:45", "3:10", "3:30" are PM
            // We know it's PM if the previous time would have been past noon
            // For simplicity: if hour is 1-3 and minutes suggest afternoon schedule, it's PM
            if hour <= 3 {
                hour += 12  // Convert to 24-hour PM time
            }
        }

        // Get start of day in local timezone
        let startOfDay = calendar.startOfDay(for: date)

        // Add the hours and minutes
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        return calendar.date(byAdding: dateComponents, to: startOfDay)
    }

    func startDate(on date: Date = Date()) -> Date? {
        parseTime(startTime, on: date)
    }

    func endDate(on date: Date = Date()) -> Date? {
        parseTime(endTime, on: date)
    }

    func isHappeningNow(at currentTime: Date = Date()) -> Bool {
        guard let start = startDate(on: currentTime),
              let end = endDate(on: currentTime) else {
            return false
        }
        return currentTime >= start && currentTime < end
    }

    func progressPercentage(at currentTime: Date = Date()) -> Double {
        guard let start = startDate(on: currentTime),
              let end = endDate(on: currentTime) else {
            return 0
        }

        let totalDuration = end.timeIntervalSince(start)
        let elapsed = currentTime.timeIntervalSince(start)

        return min(max(elapsed / totalDuration, 0), 1)
    }

    func timeRemaining(at currentTime: Date = Date()) -> TimeInterval {
        guard let end = endDate(on: currentTime) else {
            return 0
        }
        return max(end.timeIntervalSince(currentTime), 0)
    }
}

struct DailySchedule {
    let dayOfWeek: String
    let weekType: WeekType
    let blocks: [BlockTime]

    enum WeekType {
        case red
        case white
    }

    // Red Week Schedules
    static let redWeekSchedules: [String: [BlockTime]] = [
        "Monday": [
            BlockTime(block: "Ax", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "A", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "F", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "Break", startTime: "9:55", endTime: "10:10"),
            BlockTime(block: "G", startTime: "10:15", endTime: "10:55"),
            BlockTime(block: "D", startTime: "11:00", endTime: "11:40"),
            BlockTime(block: "Dx", startTime: "11:40", endTime: "12:05"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "Ex", startTime: "12:55", endTime: "1:20"),
            BlockTime(block: "E", startTime: "1:20", endTime: "2:00"),
            BlockTime(block: "C", startTime: "2:05", endTime: "2:45"),
            BlockTime(block: "Senate", startTime: "2:50", endTime: "3:30")
        ],

        "Tuesday": [
            BlockTime(block: "Gx", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "G", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "CommT", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "C", startTime: "11:00", endTime: "11:40"),
            BlockTime(block: "Cx", startTime: "11:40", endTime: "12:05"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "F", startTime: "12:55", endTime: "1:35"),
            BlockTime(block: "D", startTime: "1:40", endTime: "2:20"),
            BlockTime(block: "B", startTime: "2:25", endTime: "3:05"),
            BlockTime(block: "Meet", startTime: "3:10", endTime: "3:30")
        ],

        "Wednesday": [
            BlockTime(block: "Fx", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "F", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "E", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "Chapel", startTime: "9:55", endTime: "10:35"),
            BlockTime(block: "B", startTime: "10:40", endTime: "11:20"),
            BlockTime(block: "Bx", startTime: "11:20", endTime: "11:45"),
            BlockTime(block: "Lunch", startTime: "11:45", endTime: "12:15"),
            BlockTime(block: "Athlet", startTime: "1:30", endTime: "3:30")
        ],

        "Thursday": [
            BlockTime(block: "FacMtg", startTime: "8:30", endTime: "9:25"),
            BlockTime(block: "Ex", startTime: "9:30", endTime: "9:55"),
            BlockTime(block: "E", startTime: "9:55", endTime: "10:35"),
            BlockTime(block: "G", startTime: "10:40", endTime: "11:20"),
            BlockTime(block: "B", startTime: "11:25", endTime: "12:05"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "Ax", startTime: "12:55", endTime: "1:20"),
            BlockTime(block: "A", startTime: "1:20", endTime: "2:00"),
            BlockTime(block: "C", startTime: "2:05", endTime: "2:45"),
            BlockTime(block: "Cx", startTime: "2:45", endTime: "3:10"),
            BlockTime(block: "Meet", startTime: "3:15", endTime: "3:40")
        ],

        "Friday": [
            BlockTime(block: "Bx", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "B", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "D", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "Announ", startTime: "9:55", endTime: "10:25"),
            BlockTime(block: "E", startTime: "10:30", endTime: "11:10"),
            BlockTime(block: "ChChor", startTime: "11:15", endTime: "12:15"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "Fx", startTime: "12:55", endTime: "1:20"),
            BlockTime(block: "F", startTime: "1:20", endTime: "2:00"),
            BlockTime(block: "A", startTime: "2:05", endTime: "2:45"),
            BlockTime(block: "Meet", startTime: "2:50", endTime: "3:15")
        ],

        "Saturday": [
            BlockTime(block: "Dx", startTime: "8:45", endTime: "9:10"),
            BlockTime(block: "D", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "C", startTime: "9:55", endTime: "10:35"),
            BlockTime(block: "G", startTime: "10:40", endTime: "11:20"),
            BlockTime(block: "Gx", startTime: "11:20", endTime: "11:45"),
            BlockTime(block: "Lunch", startTime: "11:45", endTime: "12:30"),
            BlockTime(block: "Athlet", startTime: "1:30", endTime: "3:30")
        ]
    ]

    // White Week Schedules
    static let whiteWeekSchedules: [String: [BlockTime]] = [
        "Monday": [
            BlockTime(block: "Ax", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "A", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "F", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "Break", startTime: "9:55", endTime: "10:10"),
            BlockTime(block: "G", startTime: "10:15", endTime: "10:55"),
            BlockTime(block: "D", startTime: "11:00", endTime: "11:40"),
            BlockTime(block: "Dx", startTime: "11:40", endTime: "12:05"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "Ex", startTime: "12:55", endTime: "1:20"),
            BlockTime(block: "E", startTime: "1:20", endTime: "2:00"),
            BlockTime(block: "C", startTime: "2:05", endTime: "2:45"),
            BlockTime(block: "Senate", startTime: "2:50", endTime: "3:30")
        ],

        "Tuesday": [
            BlockTime(block: "Gx", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "G", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "CommT", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "C", startTime: "11:00", endTime: "11:40"),
            BlockTime(block: "Cx", startTime: "11:40", endTime: "12:05"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "F", startTime: "12:55", endTime: "1:35"),
            BlockTime(block: "D", startTime: "1:40", endTime: "2:20"),
            BlockTime(block: "B", startTime: "2:25", endTime: "3:05"),
            BlockTime(block: "Meet", startTime: "3:10", endTime: "3:30")
        ],

        "Wednesday": [
            BlockTime(block: "Dx", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "D", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "C", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "Chapel", startTime: "9:55", endTime: "10:35"),
            BlockTime(block: "G", startTime: "10:40", endTime: "11:20"),
            BlockTime(block: "Gx", startTime: "11:20", endTime: "11:45"),
            BlockTime(block: "Lunch", startTime: "11:45", endTime: "12:15"),
            BlockTime(block: "Athlet", startTime: "1:30", endTime: "3:30")
        ],

        "Thursday": [
            BlockTime(block: "FacMtg", startTime: "8:30", endTime: "9:25"),
            BlockTime(block: "Ex", startTime: "9:30", endTime: "9:55"),
            BlockTime(block: "E", startTime: "9:55", endTime: "10:35"),
            BlockTime(block: "G", startTime: "10:40", endTime: "11:20"),
            BlockTime(block: "B", startTime: "11:25", endTime: "12:05"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "Ax", startTime: "12:55", endTime: "1:20"),
            BlockTime(block: "A", startTime: "1:20", endTime: "2:00"),
            BlockTime(block: "C", startTime: "2:05", endTime: "2:45"),
            BlockTime(block: "Cx", startTime: "2:45", endTime: "3:10"),
            BlockTime(block: "Meet", startTime: "3:15", endTime: "3:40")
        ],

        "Friday": [
            BlockTime(block: "Bx", startTime: "8:00", endTime: "8:25"),
            BlockTime(block: "B", startTime: "8:25", endTime: "9:05"),
            BlockTime(block: "D", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "Announ", startTime: "9:55", endTime: "10:25"),
            BlockTime(block: "E", startTime: "10:30", endTime: "11:10"),
            BlockTime(block: "ChChor", startTime: "11:15", endTime: "12:15"),
            BlockTime(block: "Lunch", startTime: "12:05", endTime: "12:55"),
            BlockTime(block: "Fx", startTime: "12:55", endTime: "1:20"),
            BlockTime(block: "F", startTime: "1:20", endTime: "2:00"),
            BlockTime(block: "A", startTime: "2:05", endTime: "2:45"),
            BlockTime(block: "Meet", startTime: "2:50", endTime: "3:15")
        ],

        "Saturday": [
            BlockTime(block: "Fx", startTime: "8:45", endTime: "9:10"),
            BlockTime(block: "F", startTime: "9:10", endTime: "9:50"),
            BlockTime(block: "E", startTime: "9:55", endTime: "10:35"),
            BlockTime(block: "B", startTime: "10:40", endTime: "11:20"),
            BlockTime(block: "Bx", startTime: "11:20", endTime: "11:45"),
            BlockTime(block: "Lunch", startTime: "11:45", endTime: "12:30"),
            BlockTime(block: "Athlet", startTime: "1:30", endTime: "3:30")
        ]
    ]

    static func getSchedule(for date: Date, weekType: WeekType? = nil, specialSchedule: SpecialSchedule? = nil) -> [BlockTime] {
        // If a special schedule is provided, use it
        if let special = specialSchedule {
            print("📅 Using special schedule: \(special.title)")
            return special.blocks
        }

        // Otherwise, use regular Red/White week schedule
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        let dayName: String
        switch weekday {
        case 1: dayName = "Sunday"
        case 2: dayName = "Monday"
        case 3: dayName = "Tuesday"
        case 4: dayName = "Wednesday"
        case 5: dayName = "Thursday"
        case 6: dayName = "Friday"
        case 7: dayName = "Saturday"
        default: dayName = "Monday"
        }

        // Determine week type if not provided
        let currentWeekType = weekType ?? getCurrentWeekType()

        // Return appropriate schedule based on week type
        let schedules = currentWeekType == .red ? redWeekSchedules : whiteWeekSchedules
        return schedules[dayName] ?? []
    }

    static func getCurrentWeekType() -> WeekType {
        let weekNumber = Calendar.current.component(.weekOfYear, from: Date())
        return weekNumber % 2 == 0 ? .red : .white
    }

    static func getCurrentDayName() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())

        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Monday"
        }
    }

    static func getCurrentBlock(at currentTime: Date = Date()) -> BlockTime? {
        let todaySchedule = getSchedule(for: currentTime)
        let calendar = Calendar.current

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = calendar.timeZone
        let localTimeString = formatter.string(from: currentTime)

        print("📅 getCurrentBlock debug:")
        print("   Current time (UTC): \(currentTime)")
        print("   Current time (Local): \(localTimeString)")
        print("   Timezone: \(calendar.timeZone.identifier)")
        print("   Day: \(getCurrentDayName())")
        print("   Week type: \(getCurrentWeekType())")
        print("   Schedule has \(todaySchedule.count) blocks")

        for block in todaySchedule {
            if let start = block.startDate(on: currentTime),
               let end = block.endDate(on: currentTime) {
                let isNow = currentTime >= start && currentTime < end
                let startLocal = formatter.string(from: start)
                let endLocal = formatter.string(from: end)

                // Debug: show exact comparison for Block C
                if block.block == "C" {
                    print("   🔍 Block C detailed check:")
                    print("      Current: \(currentTime.timeIntervalSince1970)")
                    print("      Start: \(start.timeIntervalSince1970)")
                    print("      End: \(end.timeIntervalSince1970)")
                    print("      current >= start: \(currentTime >= start)")
                    print("      current < end: \(currentTime < end)")
                    print("      isNow: \(isNow)")
                }

                print("   Block \(block.block): \(startLocal)-\(endLocal) (defined as \(block.startTime)-\(block.endTime)) \(isNow ? "← NOW" : "")")
            }
        }

        let currentBlock = todaySchedule.first { $0.isHappeningNow(at: currentTime) }
        print("   Result: \(currentBlock?.block ?? "nil")")

        return currentBlock
    }

    static func getNextBlock(at currentTime: Date = Date()) -> BlockTime? {
        let todaySchedule = getSchedule(for: currentTime)
        return todaySchedule.first { block in
            guard let start = block.startDate(on: currentTime) else { return false }
            return start > currentTime
        }
    }
}
