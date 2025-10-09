//
//  ClassList.swift
//  Middlesex
//
//  Configuration for available classes
//

import Foundation

struct SchoolClass: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let department: ClassDepartment
    let block: String?  // Which block this X block config applies to (A, B, C, D, E, F, G)
    let xBlockDaysRed: [String]?  // Days this class uses X blocks in Red Week (for the specified block)
    let xBlockDaysWhite: [String]? // Days this class uses X blocks in White Week (for the specified block)

    init(id: String = UUID().uuidString,
         name: String,
         department: ClassDepartment,
         block: String? = nil,
         xBlockDaysRed: [String]? = nil,
         xBlockDaysWhite: [String]? = nil) {
        self.id = id
        self.name = name
        self.department = department
        self.block = block
        self.xBlockDaysRed = xBlockDaysRed
        self.xBlockDaysWhite = xBlockDaysWhite
    }
}

enum ClassDepartment: String, CaseIterable, Codable {
    case english = "English"
    case math = "Mathematics"
    case science = "Science"
    case history = "History"
    case language = "World Languages"
    case arts = "Arts"
    case music = "Music"
    case wellness = "Wellness"
    case other = "Other"

    var icon: String {
        switch self {
        case .english: return "book.fill"
        case .math: return "function"
        case .science: return "flask.fill"
        case .history: return "globe.americas.fill"
        case .language: return "character.bubble.fill"
        case .arts: return "paintbrush.fill"
        case .music: return "music.note"
        case .wellness: return "figure.run"
        case .other: return "star.fill"
        }
    }
}

// MARK: - Available Classes
// Easy to add/modify - just add new entries to this array
//
// X Block Schedule Notes:
// - If xBlockDaysRed and xBlockDaysWhite are nil, the class uses the standard schedule for its block
// - To specify custom X block days for a specific block, set the 'block' parameter (e.g., block: "F")
// - Days should match: "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
// - The 'block' parameter ensures X block config only applies when that class is in that specific block
//
// Example: Elements of Novels and Stories in F block only uses X blocks on Friday (Red) and Fri/Sat (White)
//
// Standard X Block Schedule by Block:
// Red Week:    A: Mon/Thu, B: Wed/Fri, C: Tue/Thu, D: Mon/Sat, E: Mon/Thu, F: Wed/Fri, G: Tue/Sat
// White Week:  A: Mon/Thu, B: Fri/Sat, C: Tue/Thu, D: Mon/Wed, E: Mon/Thu, F: Fri/Sat, G: Tue/Wed

struct ClassList {
    static let availableClasses: [SchoolClass] = [
        // English
        SchoolClass(
            name: "Elements of Novels and Stories",
            department: .english,
            block: "F",  // This X block config only applies when this class is in F block
            xBlockDaysRed: ["Friday"],        // Only Friday in Red Week
            xBlockDaysWhite: ["Friday", "Saturday"]  // Friday and Saturday in White Week
        ),
        SchoolClass(name: "American Literature", department: .english),
        SchoolClass(name: "British Literature", department: .english),
        SchoolClass(name: "Creative Writing", department: .english),
        SchoolClass(name: "Poetry and Prose", department: .english),

        // Mathematics
        SchoolClass(name: "Algebra and Its Functions", department: .math),
        SchoolClass(name: "Intermediate Algebra", department: .math),
        SchoolClass(name: "Geometry", department: .math),
        SchoolClass(name: "Pre-Calculus", department: .math),
        SchoolClass(name: "Calculus", department: .math),
        SchoolClass(name: "Statistics", department: .math),

        // Science
        SchoolClass(name: "Biology", department: .science),
        SchoolClass(name: "Chemistry", department: .science),
        SchoolClass(name: "Physics", department: .science),
        SchoolClass(name: "Environmental Science", department: .science),

        // History
        SchoolClass(name: "The Ancient World", department: .history),
        SchoolClass(name: "Modern World History", department: .history),
        SchoolClass(name: "U.S. History", department: .history),
        SchoolClass(name: "European History", department: .history),

        // World Languages
        SchoolClass(name: "French Part II", department: .language),
        SchoolClass(name: "Spanish I", department: .language),
        SchoolClass(name: "Spanish II", department: .language),
        SchoolClass(name: "Spanish III", department: .language),
        SchoolClass(name: "Spanish 12: Spanish Grammar", department: .language),
        SchoolClass(name: "Latin I", department: .language),
        SchoolClass(name: "Latin II", department: .language),
        SchoolClass(name: "Mandarin Chinese", department: .language),

        // Arts
        SchoolClass(name: "Studio Art", department: .arts),
        SchoolClass(name: "Photography", department: .arts),
        SchoolClass(name: "Drama", department: .arts),
        SchoolClass(name: "Art 12", department: .arts),

        // Music - Never use X blocks
        SchoolClass(name: "Music: Foundations", department: .music, xBlockDaysRed: [], xBlockDaysWhite: []),
        SchoolClass(name: "Jazz Ensemble", department: .music, xBlockDaysRed: [], xBlockDaysWhite: []),
        SchoolClass(name: "Chorus", department: .music, xBlockDaysRed: [], xBlockDaysWhite: []),
        SchoolClass(name: "Orchestra", department: .music, xBlockDaysRed: [], xBlockDaysWhite: []),

        // Wellness - Mindfulness never uses X blocks
        SchoolClass(name: "Mindfulness", department: .wellness, xBlockDaysRed: [], xBlockDaysWhite: []),
        SchoolClass(name: "Physical Education", department: .wellness),

        // Other
        SchoolClass(name: "Free Block", department: .other),
    ]

    // Helper to get classes by department
    static func classes(in department: ClassDepartment) -> [SchoolClass] {
        availableClasses.filter { $0.department == department }
    }

    // Helper to search classes
    static func search(_ query: String) -> [SchoolClass] {
        guard !query.isEmpty else { return availableClasses }
        return availableClasses.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}
