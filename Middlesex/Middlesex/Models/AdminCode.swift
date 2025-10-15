//
//  AdminCode.swift
//  Middlesex
//
//  Admin access code model with 2-hour expiry
//

import Foundation
import CloudKit

struct AdminCode: Identifiable {
    enum CodeType: String, CaseIterable, Identifiable {
        case temporary
        case permanent

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .temporary: return "Temporary"
            case .permanent: return "Permanent"
            }
        }

        var defaultDurationMinutes: Int {
            switch self {
            case .temporary: return 120
            case .permanent: return 1440 // 24 hours to redeem permanent code
            }
        }
    }

    let id: String
    let code: String
    let generatedBy: String
    let generatedAt: Date
    let expiresAt: Date
    let type: CodeType
    let durationMinutes: Int?
    let isUsed: Bool
    let usedBy: String?
    let usedAt: Date?

    var isValid: Bool {
        guard !isUsed else { return false }
        return Date() < expiresAt
    }

    var grantsPermanentAccess: Bool {
        type == .permanent
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }

    // Generate random 8-digit code
    static func generateCode(length: Int = 8) -> String {
        let digits = "0123456789"
        return String((0..<length).compactMap { _ in digits.randomElement() })
    }

    static func createTemporary(
        generatedBy: String,
        durationMinutes: Int = CodeType.temporary.defaultDurationMinutes,
        code: String? = nil
    ) -> AdminCode {
        create(
            code: code ?? generateCode(),
            generatedBy: generatedBy,
            type: .temporary,
            durationMinutes: durationMinutes
        )
    }

    static func createPermanent(
        generatedBy: String,
        durationMinutes: Int = CodeType.permanent.defaultDurationMinutes,
        code: String? = nil
    ) -> AdminCode {
        create(
            code: code ?? generateCode(),
            generatedBy: generatedBy,
            type: .permanent,
            durationMinutes: durationMinutes
        )
    }

    static func create(
        code: String,
        generatedBy: String,
        type: CodeType,
        durationMinutes: Int
    ) -> AdminCode {
        let now = Date()
        let expires = now.addingTimeInterval(TimeInterval(durationMinutes * 60))

        return AdminCode(
            id: UUID().uuidString,
            code: code,
            generatedBy: generatedBy,
            generatedAt: now,
            expiresAt: expires,
            type: type,
            durationMinutes: durationMinutes,
            isUsed: false,
            usedBy: nil,
            usedAt: nil
        )
    }

    // Create new admin code (2-hour expiry)
    static func create(generatedBy: String) -> AdminCode {
        createTemporary(generatedBy: generatedBy)
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
        if let usedBy {
            record["usedBy"] = usedBy as CKRecordValue
        }
        if let usedAt {
            record["usedAt"] = usedAt as CKRecordValue
        }
        record["codeType"] = type.rawValue as CKRecordValue
        if let durationMinutes {
            record["durationMinutes"] = NSNumber(value: durationMinutes)
        }
        record["grantsPermanent"] = (grantsPermanentAccess ? 1 : 0) as CKRecordValue
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

        let storedType: CodeType?
        if let typeString = record["codeType"] as? String {
            storedType = CodeType(rawValue: typeString)
        } else {
            storedType = nil
        }

        let grantsPermanentFlag = (record["grantsPermanent"] as? Int64 ?? 0) == 1
        let resolvedType: CodeType
        if let storedType {
            resolvedType = storedType
        } else {
            resolvedType = grantsPermanentFlag ? .permanent : .temporary
        }

        let duration: Int?
        if let durationNumber = record["durationMinutes"] as? NSNumber {
            duration = durationNumber.intValue
        } else if let durationValue = record["durationMinutes"] as? Int {
            duration = durationValue
        } else {
            let calculated = Int(expiresAt.timeIntervalSince(generatedAt) / 60)
            duration = calculated > 0 ? calculated : nil
        }

        self.id = id
        self.code = code
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
        self.type = resolvedType
        self.durationMinutes = duration
        self.isUsed = (record["isUsed"] as? Int64 ?? 0) == 1
        self.usedBy = record["usedBy"] as? String
        self.usedAt = record["usedAt"] as? Date
    }

    // Direct initializer
    init(
        id: String,
        code: String,
        generatedBy: String,
        generatedAt: Date,
        expiresAt: Date,
        type: CodeType,
        durationMinutes: Int?,
        isUsed: Bool,
        usedBy: String?,
        usedAt: Date?
    ) {
        self.id = id
        self.code = code
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
        self.type = type
        self.durationMinutes = durationMinutes
        self.isUsed = isUsed
        self.usedBy = usedBy
        self.usedAt = usedAt
    }
}
