//
//  SportsScheduleImportView.swift
//  Middlesex
//
//  Admin tool for importing sports events and schedules
//

import SwiftUI
import CloudKit

struct SportsScheduleImportView: View {
    @Environment(\.dismiss) var dismiss

    @State private var sport: SportsEvent.Sport = .football
    @State private var opponent = ""
    @State private var eventDate = Date()
    @State private var location = ""
    @State private var isHome = true
    @State private var eventType: SportsEvent.EventType = .game
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    Picker("Sport", selection: $sport) {
                        ForEach(SportsEvent.Sport.allCases, id: \.self) { sport in
                            Text(sport.rawValue).tag(sport)
                        }
                    }
                    TextField("Opponent", text: $opponent)
                }

                Section("Date & Time") {
                    DatePicker("Event Date", selection: $eventDate)
                }

                Section("Location") {
                    TextField("Location", text: $location)
                    Toggle("Home Game", isOn: $isHome)
                }

                Section("Event Type") {
                    Picker("Type", selection: $eventType) {
                        ForEach(SportsEvent.EventType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
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
            .navigationTitle("Add Sports Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(opponent.isEmpty || isSaving)
                }

                ToolbarItem(placement: .principal) {
                    if isSaving {
                        ProgressView()
                    }
                }
            }
            .alert("Event Saved!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The sports event has been saved successfully.")
            }
        }
    }

    private func saveEvent() {
        guard !opponent.isEmpty else {
            errorMessage = "Please fill in all required fields"
            return
        }

        isSaving = true
        errorMessage = nil

        let calendar = Calendar.current
        let season = getSeason(from: eventDate)

        let event = SportsEvent(
            sport: sport,
            eventType: eventType,
            opponent: opponent,
            eventDate: eventDate,
            location: location,
            isHome: isHome,
            status: .scheduled,
            season: season,
            year: calendar.component(.year, from: eventDate)
        )

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase

                let record = event.toRecord()
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

    private func getSeason(from date: Date) -> SportsEvent.Season {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)

        switch month {
        case 9, 10, 11:
            return .fall
        case 12, 1, 2:
            return .winter
        case 3, 4, 5:
            return .spring
        default:
            return .fall
        }
    }
}

#Preview {
    SportsScheduleImportView()
}
