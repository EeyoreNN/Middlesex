//
//  SpecialScheduleBuilderView.swift
//  Middlesex
//
//  Admin tool for creating custom schedules for specific dates
//

import SwiftUI
import CloudKit

struct SpecialScheduleBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared

    @State private var scheduleTitle = ""
    @State private var selectedDate = Date()
    @State private var customBlocks: [CustomBlock] = []
    @State private var showingAddBlock = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section("Schedule Information") {
                    TextField("Schedule Title", text: $scheduleTitle)
                        .font(.headline)

                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }

                Section("Blocks") {
                    ForEach(customBlocks) { block in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(block.blockName)
                                    .font(.headline)
                                Text("\(block.startTime) - \(block.endTime)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                customBlocks.removeAll { $0.id == block.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onMove { indices, newOffset in
                        customBlocks.move(fromOffsets: indices, toOffset: newOffset)
                    }

                    Button {
                        showingAddBlock = true
                    } label: {
                        Label("Add Block", systemImage: "plus.circle.fill")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Special Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(scheduleTitle.isEmpty || customBlocks.isEmpty || isSaving)
                }

                ToolbarItem(placement: .principal) {
                    if isSaving {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showingAddBlock) {
                AddBlockSheet(customBlocks: $customBlocks)
            }
            .alert("Schedule Created!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The special schedule has been saved successfully.")
            }
        }
    }

    private func saveSchedule() {
        guard !scheduleTitle.isEmpty, !customBlocks.isEmpty else {
            errorMessage = "Please provide a title and at least one block"
            return
        }

        isSaving = true
        errorMessage = nil

        let blockTimes = customBlocks.map { block in
            BlockTime(block: block.blockName, startTime: block.startTime, endTime: block.endTime)
        }

        let specialSchedule = SpecialSchedule(
            date: selectedDate,
            title: scheduleTitle,
            blocks: blockTimes,
            createdBy: preferences.userName.isEmpty ? "Admin" : preferences.userName
        )

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase

                let record = specialSchedule.toRecord()
                try await database.save(record)

                await MainActor.run {
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

struct CustomBlock: Identifiable {
    let id = UUID()
    var blockName: String
    var startTime: String
    var endTime: String
}

struct AddBlockSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var customBlocks: [CustomBlock]

    @State private var blockName = ""
    @State private var startHour = 8
    @State private var startMinute = 0
    @State private var endHour = 9
    @State private var endMinute = 0

    var body: some View {
        NavigationView {
            Form {
                Section("Block Name") {
                    TextField("e.g., A, B, Assembly, etc.", text: $blockName)
                }

                Section("Start Time") {
                    Picker("Hour", selection: $startHour) {
                        ForEach(6..<17) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }

                    Picker("Minute", selection: $startMinute) {
                        ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }

                Section("End Time") {
                    Picker("Hour", selection: $endHour) {
                        ForEach(6..<17) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }

                    Picker("Minute", selection: $endMinute) {
                        ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }
            }
            .navigationTitle("Add Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addBlock()
                    }
                    .disabled(blockName.isEmpty)
                }
            }
        }
    }

    private func addBlock() {
        let startTimeString = String(format: "%d:%02d", startHour, startMinute)
        let endTimeString = String(format: "%d:%02d", endHour, endMinute)

        let block = CustomBlock(
            blockName: blockName,
            startTime: startTimeString,
            endTime: endTimeString
        )

        customBlocks.append(block)
        dismiss()
    }
}

#Preview {
    SpecialScheduleBuilderView()
}
