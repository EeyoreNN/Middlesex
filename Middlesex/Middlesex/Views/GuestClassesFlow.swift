//
//  GuestClassesFlow.swift
//  Middlesex
//
//  Guest user schedule creation for testing/admin purposes
//

import SwiftUI
import CloudKit

struct GuestClassesFlow: View {
    @Environment(\.dismiss) var dismiss
    @State private var guestName = ""
    @State private var guestGrade = ""
    @State private var showingScheduleBuilder = false
    @State private var guestClasses: [String: GuestClassInfo] = [:] // Block -> GuestClassInfo
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveSuccess = false

    struct GuestClassInfo {
        let schoolClass: SchoolClass
        let teacher: Teacher
        let room: String
    }

    var body: some View {
        NavigationView {
            if !showingScheduleBuilder {
                // Step 1: Collect guest info
                guestInfoView
            } else if !saveSuccess {
                // Step 2: Schedule builder (modified to save to guest classes)
                guestScheduleBuilderView
            } else {
                // Step 3: Success confirmation
                successView
            }
        }
    }

    private var guestInfoView: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 80))
                    .foregroundColor(MiddlesexTheme.primaryRed)

                Text("Create Guest Schedule")
                    .font(.title.bold())

                Text("Enter student information to create a test schedule")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Student Name")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextField("John Smith", text: $guestName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Grade")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextField("9", text: $guestGrade)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            Button {
                showingScheduleBuilder = true
            } label: {
                Text("Continue to Schedule")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MiddlesexTheme.primaryRed)
                    .cornerRadius(12)
            }
            .disabled(guestName.isEmpty || guestGrade.isEmpty)
            .opacity((guestName.isEmpty || guestGrade.isEmpty) ? 0.5 : 1.0)
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .navigationTitle("Guest Classes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private var guestScheduleBuilderView: some View {
        GuestScheduleBuilder(
            guestName: guestName,
            guestGrade: guestGrade,
            onComplete: { classes in
                guestClasses = classes
                Task {
                    await saveGuestSchedule()
                }
            }
        )
    }

    private var successView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Guest Schedule Created!")
                .font(.title.bold())

            VStack(spacing: 8) {
                Text("\(guestName) - Grade \(guestGrade)")
                    .font(.headline)

                Text("\(guestClasses.count) classes saved to CloudKit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let error = saveError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(MiddlesexTheme.primaryRed)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }

    private func saveGuestSchedule() async {
        isSaving = true
        saveError = nil

        let container = CKContainer.default()
        let database = container.publicCloudDatabase

        for (block, info) in guestClasses {
            let customClass = CustomClass(
                className: info.schoolClass.name,
                teacherName: info.teacher.name,
                roomNumber: info.room,
                department: info.schoolClass.department.rawValue,
                submittedBy: "Guest: \(guestName) (Grade \(guestGrade))",
                isApproved: false // Mark as guest/test data
            )

            do {
                let record = customClass.toRecord()
                try await database.save(record)
                print("✅ Saved guest class: \(info.schoolClass.name) for block \(block)")
            } catch {
                print("❌ Failed to save guest class: \(error)")
                saveError = "Failed to save some classes: \(error.localizedDescription)"
            }
        }

        isSaving = false
        saveSuccess = true
    }
}

// MARK: - Guest Schedule Builder

struct GuestScheduleBuilder: View {
    let guestName: String
    let guestGrade: String
    let onComplete: ([String: GuestClassesFlow.GuestClassInfo]) -> Void

    @State private var currentStep = 0
    @State private var selectedClasses: [String: SchoolClass] = [:] // Block -> Class
    @State private var selectedTeachers: [String: Teacher] = [:] // Block -> Teacher
    @State private var selectedRooms: [String: String] = [:] // Block -> Room

    let blocks = ["A", "B", "C", "D", "E", "F", "G"]

    var body: some View {
        VStack(spacing: 0) {
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
                GuestTeacherRoomSelectionView(
                    guestName: guestName,
                    selectedClasses: selectedClasses,
                    selectedTeachers: $selectedTeachers,
                    selectedRooms: $selectedRooms,
                    onComplete: {
                        completeSchedule()
                    }
                )
            }
        }
        .background(MiddlesexTheme.redGradient.ignoresSafeArea())
    }

    private func completeSchedule() {
        var guestInfo: [String: GuestClassesFlow.GuestClassInfo] = [:]

        for (block, schoolClass) in selectedClasses {
            guard let teacher = selectedTeachers[block],
                  let room = selectedRooms[block] else { continue }

            guestInfo[block] = GuestClassesFlow.GuestClassInfo(
                schoolClass: schoolClass,
                teacher: teacher,
                room: room
            )
        }

        onComplete(guestInfo)
    }
}

// MARK: - Guest Teacher/Room Selection View

struct GuestTeacherRoomSelectionView: View {
    let guestName: String
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

#Preview {
    GuestClassesFlow()
}
