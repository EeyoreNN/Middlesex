//
//  MenuItem.swift
//  Middlesex
//
//  CloudKit model for menu items
//

import Foundation
import CloudKit

struct MenuItem: Identifiable, Hashable {
    let id: String
    let date: Date
    let mealType: MealType
    let title: String
    let description: String
    let category: MenuCategory
    let allergens: [String]
    let isVegetarian: Bool
    let isVegan: Bool
    let createdAt: Date
    let updatedAt: Date

    enum MealType: String, CaseIterable {
        case breakfast = "breakfast"
        case lunch = "lunch"
        case dinner = "dinner"

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum MenuCategory: String, CaseIterable {
        case main = "main"
        case side = "side"
        case dessert = "dessert"
        case beverage = "beverage"

        var displayName: String {
            rawValue.capitalized
        }
    }

    // Initialize from CloudKit record
    init?(record: CKRecord) {
        guard let id = record["id"] as? String,
              let date = record["date"] as? Date,
              let mealTypeString = record["mealType"] as? String,
              let mealType = MealType(rawValue: mealTypeString),
              let title = record["title"] as? String,
              let description = record["description"] as? String,
              let categoryString = record["category"] as? String,
              let category = MenuCategory(rawValue: categoryString),
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            return nil
        }

        self.id = id
        self.date = date
        self.mealType = mealType
        self.title = title
        self.description = description
        self.category = category

        let allergensString = record["allergens"] as? String ?? ""
        self.allergens = allergensString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

        self.isVegetarian = (record["isVegetarian"] as? Int64 ?? 0) == 1
        self.isVegan = (record["isVegan"] as? Int64 ?? 0) == 1
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Manual initializer for testing
    init(id: String = UUID().uuidString,
         date: Date,
         mealType: MealType,
         title: String,
         description: String,
         category: MenuCategory,
         allergens: [String] = [],
         isVegetarian: Bool = false,
         isVegan: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.title = title
        self.description = description
        self.category = category
        self.allergens = allergens
        self.isVegetarian = isVegetarian
        self.isVegan = isVegan
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Convert to CloudKit record
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: "MenuItem")
        record["id"] = id as CKRecordValue
        record["date"] = date as CKRecordValue
        record["mealType"] = mealType.rawValue as CKRecordValue
        record["title"] = title as CKRecordValue
        record["description"] = description as CKRecordValue
        record["category"] = category.rawValue as CKRecordValue
        record["allergens"] = allergens.joined(separator: ", ") as CKRecordValue
        record["isVegetarian"] = (isVegetarian ? 1 : 0) as CKRecordValue
        record["isVegan"] = (isVegan ? 1 : 0) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        return record
    }
}
