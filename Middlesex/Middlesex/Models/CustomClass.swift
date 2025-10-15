//
//  CustomClass.swift
//  Middlesex
//
//  User-submitted custom classes that aren't in the official list
//

import Foundation
import CloudKit

struct CustomClass: Identifiable {
    let id: String
    let className: String
    let teacherName: String
    let roomNumber: String
    let department: String
    let submittedBy: String
    let submittedAt: Date
    let isApproved: Bool
    let recordID: CKRecord.ID?

    init(id: String = UUID().uuidString,
         className: String,
         teacherName: String,
         roomNumber: String,
         department: String,
         submittedBy: String,
         submittedAt: Date = Date(),
         isApproved: Bool = false,
         recordID: CKRecord.ID? = nil) {
        self.id = id
        self.className = className
        self.teacherName = teacherName
        self.roomNumber = roomNumber
        self.department = department
        self.submittedBy = submittedBy
        self.submittedAt = submittedAt
        self.isApproved = isApproved
        self.recordID = recordID
    }

    init?(from record: CKRecord) {
        guard let id = record["id"] as? String,
              let className = record["className"] as? String,
              let teacherName = record["teacherName"] as? String,
              let roomNumber = record["roomNumber"] as? String,
              let department = record["department"] as? String,
              let submittedBy = record["submittedBy"] as? String,
              let submittedAt = record["submittedAt"] as? Date else {
            return nil
        }

        self.id = id
        self.className = className
        self.teacherName = teacherName
        self.roomNumber = roomNumber
        self.department = department
        self.submittedBy = submittedBy
        self.submittedAt = submittedAt
        self.isApproved = (record["isApproved"] as? Int64 == 1)
        self.recordID = record.recordID
    }

    func toRecord() -> CKRecord {
        let record = recordID.map { CKRecord(recordType: "CustomClass", recordID: $0) } ?? CKRecord(recordType: "CustomClass")
        record["id"] = id as CKRecordValue
        record["className"] = className as CKRecordValue
        record["teacherName"] = teacherName as CKRecordValue
        record["roomNumber"] = roomNumber as CKRecordValue
        record["department"] = department as CKRecordValue
        record["submittedBy"] = submittedBy as CKRecordValue
        record["submittedAt"] = submittedAt as CKRecordValue
        record["isApproved"] = (isApproved ? 1 : 0) as CKRecordValue
        return record
    }
}
