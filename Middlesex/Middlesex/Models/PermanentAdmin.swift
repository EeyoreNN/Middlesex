//
//  PermanentAdmin.swift
//  Middlesex
//
//  CloudKit model describing a permanent administrator.
//

import Foundation
import CloudKit

struct PermanentAdmin: Identifiable {
    let id: String
    let recordID: CKRecord.ID
    let userId: String
    let displayName: String?
    let createdAt: Date
    let canGenerateCodes: Bool
    let sourceCode: String?

    init?(record: CKRecord) {
        guard let userId = record["userId"] as? String else {
            return nil
        }

        self.recordID = record.recordID
        self.id = (record["id"] as? String) ?? record.recordID.recordName
        self.userId = userId
        self.displayName = record["displayName"] as? String
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? Date()
        self.canGenerateCodes = (record["canGenerateCodes"] as? Int64 ?? 0) > 0
        self.sourceCode = record["sourceCode"] as? String
    }

    static func makeRecord(userId: String, displayName: String?, sourceCode: String) -> CKRecord {
        let record = CKRecord(recordType: "PermanentAdmin")
        record["id"] = UUID().uuidString as CKRecordValue
        record["userId"] = userId as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["canGenerateCodes"] = 1 as CKRecordValue
        record["sourceCode"] = sourceCode as CKRecordValue

        if let displayName, !displayName.isEmpty {
            record["displayName"] = displayName as CKRecordValue
        }

        return record
    }
}
