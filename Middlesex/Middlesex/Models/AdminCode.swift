//
//  AdminCode.swift
//  Middlesex
//
//  Admin access code model with 2-hour expiry
//

import Foundation
import CloudKit

struct AdminCode: Identifiable {
    let id: String
    let code: String
    let generatedBy: String
    let generatedAt: Date
    let expiresAt: Date
    var isUsed: Bool
    var usedBy: String?
    var usedAt: Date?

    var isValid: Bool {
        !isUsed && Date() < expiresAt
    }

    // Generate random 8-digit code
    static func generateCode() -> String {
        let digits = "0123456789"
        return String((0..<8).map { _ in digits.randomElement()! })
    }

    // Create new admin code (2-hour expiry)
    static func create(generatedBy: String) -> AdminCode {
        let now = Date()
        return AdminCode(
            id: UUID().uuidString,
            code: generateCode(),
            generatedBy: generatedBy,
            generatedAt: now,
            expiresAt: now.addingTimeInterval(2 * 60 * 60), // 2 hours
            isUsed: false,
            usedBy: nil,
            usedAt: nil
        )
    }

    // Convert to CloudKit record
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "AdminCode")
        record["id"] = id as CKRecordValue
        record["code"] = code as CKRecordValue
        record["generatedBy"] = generatedBy as CKRecordValue
        record["generatedAt"] = generatedAt as CKRecordValue
        record["expiresAt"] = expiresAt as CKRecordValue
        record["isUsed"] = (isUsed ? 1 : 0) as CKRecordValue
        if let usedBy = usedBy {
            record["usedBy"] = usedBy as CKRecordValue
        }
        if let usedAt = usedAt {
            record["usedAt"] = usedAt as CKRecordValue
        }
        return record
    }

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let code = record["code"] as? String,
              let generatedBy = record["generatedBy"] as? String,
              let generatedAt = record["generatedAt"] as? Date,
              let expiresAt = record["expiresAt"] as? Date else {
            return nil
        }

        self.id = id
        self.code = code
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
        self.isUsed = (record["isUsed"] as? Int64 ?? 0) != 0
        self.usedBy = record["usedBy"] as? String
        self.usedAt = record["usedAt"] as? Date
    }

    // Direct initializer
    init(id: String, code: String, generatedBy: String, generatedAt: Date, expiresAt: Date, isUsed: Bool, usedBy: String?, usedAt: Date?) {
        self.id = id
        self.code = code
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
        self.isUsed = isUsed
        self.usedBy = usedBy
        self.usedAt = usedAt
    }
}
