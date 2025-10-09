//
//  XBlockMapping.swift
//  Middlesex
//
//  Crowd-sourced X block day mappings for classes
//

import Foundation
import CloudKit

struct XBlockMapping: Identifiable {
    let id: String
    let className: String
    let teacherName: String
    let weekType: String // "Red" or "White"
    let xBlockDays: [String] // ["Monday", "Wednesday", etc.]
    let voteCount: Int
    let submittedBy: String
    let submittedAt: Date

    init(id: String = UUID().uuidString,
         className: String,
         teacherName: String,
         weekType: String,
         xBlockDays: [String],
         voteCount: Int = 1,
         submittedBy: String,
         submittedAt: Date = Date()) {
        self.id = id
        self.className = className
        self.teacherName = teacherName
        self.weekType = weekType
        self.xBlockDays = xBlockDays
        self.voteCount = voteCount
        self.submittedBy = submittedBy
        self.submittedAt = submittedAt
    }

    init?(from record: CKRecord) {
        guard let id = record["id"] as? String,
              let className = record["className"] as? String,
              let teacherName = record["teacherName"] as? String,
              let weekType = record["weekType"] as? String,
              let xBlockDaysJSON = record["xBlockDays"] as? String,
              let submittedBy = record["submittedBy"] as? String,
              let submittedAt = record["submittedAt"] as? Date else {
            return nil
        }

        // Decode JSON string to array
        let xBlockDays = (try? JSONDecoder().decode([String].self, from: xBlockDaysJSON.data(using: .utf8) ?? Data())) ?? []

        self.id = id
        self.className = className
        self.teacherName = teacherName
        self.weekType = weekType
        self.xBlockDays = xBlockDays
        self.voteCount = Int(record["voteCount"] as? Int64 ?? 1)
        self.submittedBy = submittedBy
        self.submittedAt = submittedAt
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "XBlockMapping")
        record["id"] = id as CKRecordValue
        record["className"] = className as CKRecordValue
        record["teacherName"] = teacherName as CKRecordValue
        record["weekType"] = weekType as CKRecordValue

        // Encode array to JSON string
        if let jsonData = try? JSONEncoder().encode(xBlockDays),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["xBlockDays"] = jsonString as CKRecordValue
        }

        record["voteCount"] = voteCount as CKRecordValue
        record["submittedBy"] = submittedBy as CKRecordValue
        record["submittedAt"] = submittedAt as CKRecordValue
        return record
    }

    // MARK: - CloudKit Helper Methods

    /// Save or update this X block mapping in CloudKit
    static func save(_ mapping: XBlockMapping) async throws {
        let container = CKContainer.default()
        let database = container.publicCloudDatabase
        let record = mapping.toRecord()
        try await database.save(record)
    }

    /// Find the most voted X block mapping for a given class
    static func findPopularMapping(className: String, teacherName: String, weekType: String) async throws -> XBlockMapping? {
        let container = CKContainer.default()
        let database = container.publicCloudDatabase

        let classNamePredicate = NSPredicate(format: "className == %@", className)
        let teacherPredicate = NSPredicate(format: "teacherName == %@", teacherName)
        let weekTypePredicate = NSPredicate(format: "weekType == %@", weekType)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [classNamePredicate, teacherPredicate, weekTypePredicate])

        let query = CKQuery(recordType: "XBlockMapping", predicate: compound)
        query.sortDescriptors = [NSSortDescriptor(key: "voteCount", ascending: false)]

        let results = try await database.records(matching: query, resultsLimit: 1)

        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let mapping = XBlockMapping(from: record) {
                    return mapping
                }
            }
        }

        return nil
    }

    /// Check if a matching configuration already exists, and if so, increment its vote count
    static func submitOrIncrementVote(className: String, teacherName: String, weekType: String, xBlockDays: [String], submittedBy: String) async throws -> XBlockMapping {
        let container = CKContainer.default()
        let database = container.publicCloudDatabase

        // Search for existing exact match
        let classNamePredicate = NSPredicate(format: "className == %@", className)
        let teacherPredicate = NSPredicate(format: "teacherName == %@", teacherName)
        let weekTypePredicate = NSPredicate(format: "weekType == %@", weekType)

        // Encode the xBlockDays for comparison
        let xBlockDaysJSON = (try? String(data: JSONEncoder().encode(xBlockDays), encoding: .utf8)) ?? "[]"
        let xBlockDaysPredicate = NSPredicate(format: "xBlockDays == %@", xBlockDaysJSON)

        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [
            classNamePredicate, teacherPredicate, weekTypePredicate, xBlockDaysPredicate
        ])

        let query = CKQuery(recordType: "XBlockMapping", predicate: compound)
        let results = try await database.records(matching: query, resultsLimit: 1)

        // Check if we found an exact match
        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                // Increment vote count
                let currentVotes = record["voteCount"] as? Int64 ?? 1
                record["voteCount"] = (currentVotes + 1) as CKRecordValue

                let updatedRecord = try await database.save(record)
                if let mapping = XBlockMapping(from: updatedRecord) {
                    return mapping
                }
            }
        }

        // No match found, create new entry
        let newMapping = XBlockMapping(
            className: className,
            teacherName: teacherName,
            weekType: weekType,
            xBlockDays: xBlockDays,
            voteCount: 1,
            submittedBy: submittedBy
        )

        try await save(newMapping)
        return newMapping
    }

    /// Check if a popular configuration (3+ votes) exists for auto-population
    static func shouldAutoPopulate(className: String, teacherName: String, weekType: String) async throws -> [String]? {
        if let popular = try await findPopularMapping(className: className, teacherName: teacherName, weekType: weekType) {
            if popular.voteCount >= 3 {
                return popular.xBlockDays
            }
        }
        return nil
    }
}
