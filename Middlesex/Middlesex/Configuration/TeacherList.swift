//
//  TeacherList.swift
//  Middlesex
//
//  Configuration for teachers and classrooms
//

import Foundation

struct Teacher: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let department: ClassDepartment
    let defaultRoom: String

    init(id: String = UUID().uuidString, name: String, department: ClassDepartment, defaultRoom: String) {
        self.id = id
        self.name = name
        self.department = department
        self.defaultRoom = defaultRoom
    }
}

// MARK: - Available Teachers
// Easy to add/modify - just add new entries to this array

struct TeacherList {
    static let availableTeachers: [Teacher] = [
        // English Department
        Teacher(name: "Mr. Smith", department: .english, defaultRoom: "101"),
        Teacher(name: "Ms. Johnson", department: .english, defaultRoom: "102"),
        Teacher(name: "Dr. Williams", department: .english, defaultRoom: "103"),

        // Mathematics Department
        Teacher(name: "Mr. Brown", department: .math, defaultRoom: "201"),
        Teacher(name: "Ms. Davis", department: .math, defaultRoom: "202"),
        Teacher(name: "Dr. Miller", department: .math, defaultRoom: "203"),

        // Science Department
        Teacher(name: "Mr. Wilson", department: .science, defaultRoom: "301"),
        Teacher(name: "Ms. Moore", department: .science, defaultRoom: "302"),
        Teacher(name: "Dr. Taylor", department: .science, defaultRoom: "303"),

        // History Department
        Teacher(name: "Mr. Anderson", department: .history, defaultRoom: "401"),
        Teacher(name: "Ms. Thomas", department: .history, defaultRoom: "402"),
        Teacher(name: "Dr. Jackson", department: .history, defaultRoom: "403"),

        // World Languages Department
        Teacher(name: "Mme. Martin", department: .language, defaultRoom: "501"),
        Teacher(name: "Sr. Garcia", department: .language, defaultRoom: "502"),
        Teacher(name: "Mr Jean", department: .language, defaultRoom: "503"),

        // Arts Department
        Teacher(name: "Mr. Clark", department: .arts, defaultRoom: "Art Studio"),
        Teacher(name: "Ms. Rodriguez", department: .arts, defaultRoom: "Theater"),

        // Music Department
        Teacher(name: "Mr. Lewis", department: .music, defaultRoom: "Music Hall"),
        Teacher(name: "Ms. Walker", department: .music, defaultRoom: "Choir Room"),

        // Wellness Department
        Teacher(name: "Coach Martinez", department: .wellness, defaultRoom: "Gym"),
        Teacher(name: "Mr. White", department: .wellness, defaultRoom: "Wellness Center"),
    ]

    // Helper to get teachers by department
    static func teachers(in department: ClassDepartment) -> [Teacher] {
        availableTeachers.filter { $0.department == department }
    }

    // Helper to search teachers
    static func search(_ query: String) -> [Teacher] {
        guard !query.isEmpty else { return availableTeachers }
        return availableTeachers.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Room Numbers

struct RoomList {
    static let availableRooms: [String] = [
        // Academic Buildings
        "101", "102", "103", "104", "105",
        "201", "202", "203", "204", "205",
        "301", "302", "303", "304", "305",
        "401", "402", "403", "404", "405",
        "501", "502", "503", "504", "505",

        // Special Rooms
        "Art Studio",
        "Theater",
        "Music Hall",
        "Choir Room",
        "Band Room",
        "Gym",
        "Wellness Center",
        "Library",
        "Science Lab A",
        "Science Lab B",
        "Computer Lab",
    ]
}
