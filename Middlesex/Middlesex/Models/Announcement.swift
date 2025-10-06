//
//  Announcement.swift
//  Middlesex
//
//  CloudKit model for school announcements
//

import Foundation
import CloudKit

struct Announcement: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let publishDate: Date
    let expiryDate: Date
    let priority: Priority
    let category: Category
    let author: String
    let imageURL: String?
    let isActive: Bool
    let isPinned: Bool
    let isCritical: Bool
    let createdAt: Date
    let updatedAt: Date

    enum Priority: String, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"

        var displayName: String {
            rawValue.capitalized
        }

        var sortOrder: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }

    enum Category: String, CaseIterable {
        case academic = "academic"
        case sports = "sports"
        case events = "events"
        case general = "general"

        var displayName: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .academic: return "book.fill"
            case .sports: return "figure.run"
            case .events: return "calendar"
            case .general: return "megaphone.fill"
            }
        }
    }

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let title = record["title"] as? String,
              let body = record["body"] as? String,
              let publishDate = record["publishDate"] as? Date,
              let expiryDate = record["expiryDate"] as? Date,
              let priorityString = record["priority"] as? String,
              let priority = Priority(rawValue: priorityString),
              let categoryString = record["category"] as? String,
              let category = Category(rawValue: categoryString),
              let author = record["author"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            return nil
        }

        self.id = id
        self.title = title
        self.body = body
        self.publishDate = publishDate
        self.expiryDate = expiryDate
        self.priority = priority
        self.category = category
        self.author = author
        self.imageURL = record["imageURL"] as? String
        self.isActive = (record["isActive"] as? Int64 ?? 0) == 1
        self.isPinned = (record["isPinned"] as? Int64 ?? 0) == 1
        self.isCritical = (record["isCritical"] as? Int64 ?? 0) == 1
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Manual initializer
    init(id: String = UUID().uuidString,
         title: String,
         body: String,
         publishDate: Date = Date(),
         expiryDate: Date,
         priority: Priority = .medium,
         category: Category,
         author: String,
         imageURL: String? = nil,
         isActive: Bool = true,
         isPinned: Bool = false,
         isCritical: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.publishDate = publishDate
        self.expiryDate = expiryDate
        self.priority = priority
        self.category = category
        self.author = author
        self.imageURL = imageURL
        self.isActive = isActive
        self.isPinned = isPinned
        self.isCritical = isCritical
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Convert to CloudKit record
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "Announcement")
        record["id"] = id as CKRecordValue
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue
        record["publishDate"] = publishDate as CKRecordValue
        record["expiryDate"] = expiryDate as CKRecordValue
        record["priority"] = priority.rawValue as CKRecordValue
        record["category"] = category.rawValue as CKRecordValue
        record["author"] = author as CKRecordValue
        if let imageURL = imageURL {
            record["imageURL"] = imageURL as CKRecordValue
        }
        record["isActive"] = (isActive ? 1 : 0) as CKRecordValue
        record["isPinned"] = (isPinned ? 1 : 0) as CKRecordValue
        record["isCritical"] = (isCritical ? 1 : 0) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        return record
    }

    var isCurrentlyActive: Bool {
        isActive && Date() >= publishDate && Date() <= expiryDate
    }
}
