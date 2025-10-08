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

    init(id: String = UUID().uuidString, name: String, department: ClassDepartment) {
        self.id = id
        self.name = name
        self.department = department
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

struct ClassList {
    static let availableClasses: [SchoolClass] = [
        // English
        SchoolClass(name: "Elements of Novels and Stories", department: .english),
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

        // Music
        SchoolClass(name: "Music: Foundations", department: .music),
        SchoolClass(name: "Jazz Ensemble", department: .music),
        SchoolClass(name: "Chorus", department: .music),
        SchoolClass(name: "Orchestra", department: .music),

        // Wellness
        SchoolClass(name: "Mindfulness", department: .wellness),
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
