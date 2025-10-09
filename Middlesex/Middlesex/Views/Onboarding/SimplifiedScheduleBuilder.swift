//
//  SimplifiedScheduleBuilder.swift
//  Middlesex
//
//  Simplified block-by-block schedule builder
//

import SwiftUI

struct SimplifiedScheduleBuilder: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var currentStep = 0
    @State private var selectedClasses: [String: SchoolClass] = [:] // Block -> Class
    @State private var selectedTeachers: [String: Teacher] = [:] // Block -> Teacher
    @State private var selectedRooms: [String: String] = [:] // Block -> Room
    @State private var showingExtracurricular = false

    let blocks = ["A", "B", "C", "D", "E", "F", "G"]
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !showingExtracurricular {
                // Progress bar
                ProgressView(value: Double(currentStep), total: Double(blocks.count))
                    .tint(MiddlesexTheme.primaryRed)
                    .padding()
                    .background(Color.clear)

                if currentStep < blocks.count {
                    // Block selection step
                    BlockSelectionView(
                        block: blocks[currentStep],
                        alreadySelected: Array(selectedClasses.values),
                        onSelect: { schoolClass in
                            selectedClasses[blocks[currentStep]] = schoolClass
                            currentStep += 1
                        }
                    )
                } else {
                    // Teacher/Room selection for all classes
                    TeacherRoomSelectionView(
                        selectedClasses: selectedClasses,
                        selectedTeachers: $selectedTeachers,
                        selectedRooms: $selectedRooms,
                        onComplete: {
                            saveSchedule()
                            showingExtracurricular = true
                        }
                    )
                }
            } else {
                // Extracurricular questions
                ExtracurricularQuestionsView(
                    selectedClasses: selectedClasses,
                    onComplete: onComplete
                )
            }
        }
        .background(MiddlesexTheme.redGradient.ignoresSafeArea())
    }

    private func saveSchedule() {
        // Save to UserPreferences for Red Week
        for (block, schoolClass) in selectedClasses {
            let teacherName: String
            let roomName: String

            // Handle free blocks specially
            if schoolClass.name == "Free Block" {
                teacherName = "Free"
                roomName = "Free"
            } else {
                guard let teacher = selectedTeachers[block],
                      let room = selectedRooms[block] else { continue }
                teacherName = teacher.name
                roomName = room
            }

            let userClass = UserClass(
                className: schoolClass.name,
                teacher: teacherName,
                room: roomName,
                color: "#C8102E"
            )

            // Map block letters to period numbers (A=1, B=2, etc.)
            if let blockIndex = blocks.firstIndex(of: block) {
                preferences.setClass(userClass, for: blockIndex + 1, weekType: .red)
            }
        }
    }
}

// MARK: - Block Selection View

struct BlockSelectionView: View {
    let block: String
    let alreadySelected: [SchoolClass]
    let onSelect: (SchoolClass) -> Void

    @State private var searchText = ""
    @State private var selectedDepartment: ClassDepartment?
    @State private var showingCustomClassRequest = false

    var availableClasses: [SchoolClass] {
        let alreadySelectedIDs = Set(alreadySelected.map { $0.id })
        var classes = ClassList.availableClasses.filter { !alreadySelectedIDs.contains($0.id) }

        if let department = selectedDepartment {
            classes = classes.filter { $0.department == department }
        }

        if !searchText.isEmpty {
            classes = classes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return classes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("What's your \(block) Block class?")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search classes", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.primary)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
            .background(Color.clear)

            // Department filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    DepartmentChip(
                        department: nil,
                        isSelected: selectedDepartment == nil,
                        action: { selectedDepartment = nil }
                    )

                    ForEach(ClassDepartment.allCases, id: \.self) { department in
                        DepartmentChip(
                            department: department,
                            isSelected: selectedDepartment == department,
                            action: { selectedDepartment = department }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            // Class list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(availableClasses) { schoolClass in
                        ClassCard(schoolClass: schoolClass) {
                            onSelect(schoolClass)
                        }
                    }

                    // Request custom class button
                    Button {
                        showingCustomClassRequest = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(MiddlesexTheme.primaryRed)
                                .frame(width: 50, height: 50)
                                .background(Color.white)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Class Not Listed?")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("Request to add a custom class")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(MiddlesexTheme.cardBackground)
            .cornerRadius(30, corners: [.topLeft, .topRight])
        }
        .sheet(isPresented: $showingCustomClassRequest) {
            CustomClassRequestView()
        }
    }
}

struct DepartmentChip: View {
    let department: ClassDepartment?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let department = department {
                    Image(systemName: department.icon)
                        .font(.caption)
                }

                Text(department?.rawValue ?? "All")
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.white.opacity(0.3))
            .foregroundColor(isSelected ? MiddlesexTheme.primaryRed : .white)
            .cornerRadius(20)
        }
    }
}

struct ClassCard: View {
    let schoolClass: SchoolClass
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: schoolClass.department.icon)
                    .font(.title2)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                    .frame(width: 50, height: 50)
                    .background(MiddlesexTheme.primaryRed.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(schoolClass.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Text(schoolClass.department.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(MiddlesexTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Teacher/Room Selection View

struct TeacherRoomSelectionView: View {
    let selectedClasses: [String: SchoolClass]
    @Binding var selectedTeachers: [String: Teacher]
    @Binding var selectedRooms: [String: String]
    let onComplete: () -> Void

    @State private var currentClassIndex = 0

    var sortedBlocks: [String] {
        selectedClasses.keys.sorted()
    }

    var currentBlock: String? {
        guard currentClassIndex < sortedBlocks.count else { return nil }
        return sortedBlocks[currentClassIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if let block = currentBlock, let schoolClass = selectedClasses[block] {
                // Progress
                ProgressView(value: Double(currentClassIndex), total: Double(sortedBlocks.count))
                    .tint(MiddlesexTheme.primaryRed)
                    .padding()
                    .background(Color.clear)

                TeacherRoomPicker(
                    block: block,
                    schoolClass: schoolClass,
                    selectedTeacher: $selectedTeachers[block],
                    selectedRoom: $selectedRooms[block],
                    onNext: {
                        if currentClassIndex < sortedBlocks.count - 1 {
                            currentClassIndex += 1
                        } else {
                            onComplete()
                        }
                    }
                )
            }
        }
    }
}

struct TeacherRoomPicker: View {
    let block: String
    let schoolClass: SchoolClass
    @Binding var selectedTeacher: Teacher?
    @Binding var selectedRoom: String?
    let onNext: () -> Void

    var teachers: [Teacher] {
        TeacherList.teachers(in: schoolClass.department)
    }

    var isFreeBlock: Bool {
        schoolClass.name == "Free Block"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("\(block) Block")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Text(schoolClass.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()

            if isFreeBlock {
                // Free block - no teacher/room needed
                VStack(spacing: 20) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))

                    Text("No teacher or room needed for free blocks")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .onAppear {
                    // Auto-set placeholder values for free block
                    selectedTeacher = nil
                    selectedRoom = "Free"
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Teacher selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Teacher")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ForEach(teachers) { teacher in
                                Button {
                                    selectedTeacher = teacher
                                    selectedRoom = teacher.defaultRoom
                                } label: {
                                    HStack {
                                        Text(teacher.name)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if selectedTeacher?.id == teacher.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(MiddlesexTheme.primaryRed)
                                        }
                                    }
                                    .padding()
                                    .background(MiddlesexTheme.cardBackground)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                        }

                        // Room selection
                        if selectedTeacher != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Room Number")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)

                                Menu {
                                    ForEach(RoomList.availableRooms, id: \.self) { room in
                                        Button(room) {
                                            selectedRoom = room
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedRoom ?? "Select room")
                                            .foregroundColor(selectedRoom == nil ? .gray : .primary)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(MiddlesexTheme.cardBackground)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color.white.opacity(0.1))
                .cornerRadius(30, corners: [.topLeft, .topRight])
            }

            // Next button
            Button {
                onNext()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MiddlesexTheme.primaryRed)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            .disabled(!isFreeBlock && (selectedTeacher == nil || selectedRoom == nil))
            .opacity((!isFreeBlock && (selectedTeacher == nil || selectedRoom == nil)) ? 0.5 : 1.0)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    SimplifiedScheduleBuilder(onComplete: {})
}
