//
//  SpecialSchedule.swift
//  Middlesex
//
//  CloudKit model for special/custom daily schedules
//

import Foundation
import CloudKit

struct SpecialSchedule: Identifiable, Codable {
    let id: String
    let date: Date? // The specific date this schedule applies to
    let title: String // e.g., "Early Dismissal", "Assembly Schedule"
    let blocks: [BlockTime] // Custom blocks for this day
    let createdBy: String
    let createdAt: Date
    let isActive: Bool

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let date = record["date"] as? Date,
              let title = record["title"] as? String,
              let blocksData = record["blocksData"] as? String,
              let createdBy = record["createdBy"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        self.id = id
        self.date = date
        self.title = title
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isActive = (record["isActive"] as? Int64 ?? 1) == 1

        // Decode blocks from JSON string
        if let data = blocksData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([BlockTimeData].self, from: data) {
            self.blocks = decoded.map { BlockTime(block: $0.block, startTime: $0.startTime, endTime: $0.endTime) }
        } else {
            self.blocks = []
        }
    }

    // Manual initializer
    init(id: String = UUID().uuidString,
         date: Date,
         title: String,
         blocks: [BlockTime],
         createdBy: String,
         createdAt: Date = Date(),
         isActive: Bool = true) {
        self.id = id
        self.date = date
        self.title = title
        self.blocks = blocks
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isActive = isActive
    }

    // Convert to CloudKit record
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "SpecialSchedule")
        record["id"] = id as CKRecordValue
        if let date = date {
            record["date"] = date as CKRecordValue
        }
        record["title"] = title as CKRecordValue
        record["createdBy"] = createdBy as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue

        // Encode blocks to JSON string
        let blockData = blocks.map { BlockTimeData(block: $0.block, startTime: $0.startTime, endTime: $0.endTime) }
        if let jsonData = try? JSONEncoder().encode(blockData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            record["blocksData"] = jsonString as CKRecordValue
        }

        return record
    }
}

// Helper struct for JSON encoding/decoding
struct BlockTimeData: Codable {
    let block: String
    let startTime: String
    let endTime: String
}
