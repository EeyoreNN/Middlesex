//
//  XBlockScheduleResolver.swift
//  Middlesex
//
//  Centralized X block schedule resolution with three-tier system:
//  1. User's personal settings (highest priority)
//  2. Crowd-sourced data from CloudKit (middle priority)
//  3. Standard schedule fallback (lowest priority)
//

import Foundation

struct XBlockScheduleResolver {

    // MARK: - Standard X Block Schedules

    // Standard X Block Schedule by Block (from school documentation)
    private static let standardSchedule: [String: [ClassSchedule.WeekType: [String]]] = [
        "A": [
            .red: ["Monday", "Thursday"],
            .white: ["Monday", "Thursday"]
        ],
        "B": [
            .red: ["Wednesday", "Friday"],
            .white: ["Friday", "Saturday"]
        ],
        "C": [
            .red: ["Tuesday", "Thursday"],  // TuesdayR: Cx at 11:40-12:05, ThursdayR: Cx at 2:45-3:10
            .white: ["Tuesday", "Thursday"]  // TuesdayW: Cx at 11:40-12:05, ThursdayW: Cx at 2:45-3:10
        ],
        "D": [
            .red: ["Monday", "Saturday"],
            .white: ["Monday", "Wednesday"]
        ],
        "E": [
            .red: ["Monday", "Thursday"],
            .white: ["Monday", "Thursday"]
        ],
        "F": [
            .red: ["Wednesday", "Friday"],
            .white: ["Friday", "Saturday"]
        ],
        "G": [
            .red: ["Tuesday", "Saturday"],
            .white: ["Tuesday", "Wednesday"]
        ]
    ]

    // MARK: - Public Resolution Methods

    /// Get X block days using three-tier resolution system
    /// - Parameters:
    ///   - userClass: The user's class (may have personal X block settings)
    ///   - blockLetter: The block letter (A-G)
    ///   - weekType: Red or White week
    /// - Returns: Array of day names when this class uses X blocks
    static func getXBlockDays(for userClass: UserClass?, blockLetter: String, weekType: ClassSchedule.WeekType) async -> [String] {
        // Tier 1: Check user's personal settings first
        if let userClass = userClass,
           let userDays = userClass.xBlockDays(for: weekType) {
            return userDays
        }

        // Tier 2: Try crowd-sourced data (3+ votes)
        if let userClass = userClass,
           let crowdDays = await getCrowdSourcedXBlockDays(
            className: userClass.className,
            teacherName: userClass.teacher,
            blockLetter: blockLetter,
            weekType: weekType
           ) {
            return crowdDays
        }

        // Tier 3: Fall back to standard schedule for this block
        return getStandardXBlockDays(for: blockLetter, weekType: weekType)
    }

    /// Check if a class uses X blocks on a specific day
    /// - Parameters:
    ///   - userClass: The user's class
    ///   - blockLetter: The block letter (A-G)
    ///   - dayName: Day name (e.g., "Monday", "Tuesday")
    ///   - weekType: Red or White week
    /// - Returns: True if the class uses X blocks on this day
    static func usesXBlock(
        userClass: UserClass?,
        blockLetter: String,
        dayName: String,
        weekType: ClassSchedule.WeekType
    ) async -> Bool {
        let xBlockDays = await getXBlockDays(
            for: userClass,
            blockLetter: blockLetter,
            weekType: weekType
        )
        return xBlockDays.contains(dayName)
    }

    // MARK: - Standard Schedule Lookup

    /// Get standard X block days for a given block and week type
    static func getStandardXBlockDays(for blockLetter: String, weekType: ClassSchedule.WeekType) -> [String] {
        return standardSchedule[blockLetter]?[weekType] ?? []
    }

    // MARK: - Crowd-Sourced Data

    /// Fetch crowd-sourced X block days from CloudKit (requires 3+ votes)
    private static func getCrowdSourcedXBlockDays(
        className: String,
        teacherName: String,
        blockLetter: String,
        weekType: ClassSchedule.WeekType
    ) async -> [String]? {
        do {
            let weekTypeString = weekType == .red ? "Red" : "White"

            // Use XBlockMapping to check for popular configuration
            if let days = try await XBlockMapping.shouldAutoPopulate(
                className: className,
                teacherName: teacherName,
                weekType: weekTypeString
            ) {
                return days
            }
        } catch {
            print("⚠️ Error fetching crowd-sourced X block data: \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - Pre-population Helper

    /// Try to fetch crowd-sourced X block days for pre-populating UI
    /// Returns nil if no popular configuration exists (< 3 votes)
    static func fetchPopularXBlockDays(
        className: String,
        teacherName: String,
        weekType: ClassSchedule.WeekType
    ) async -> [String]? {
        return await getCrowdSourcedXBlockDays(
            className: className,
            teacherName: teacherName,
            blockLetter: "", // Not used in crowd-sourced lookup
            weekType: weekType
        )
    }

    // MARK: - Submission Helper

    /// Submit user's X block configuration to CloudKit to help others
    static func submitXBlockConfiguration(
        className: String,
        teacherName: String,
        weekType: ClassSchedule.WeekType,
        xBlockDays: [String],
        submittedBy: String
    ) async throws {
        let weekTypeString = weekType == .red ? "Red" : "White"

        _ = try await XBlockMapping.submitOrIncrementVote(
            className: className,
            teacherName: teacherName,
            weekType: weekTypeString,
            xBlockDays: xBlockDays,
            submittedBy: submittedBy
        )
    }
}
