//
//  AnnouncementComposerView.swift
//  Middlesex
//
//  Admin interface for creating and sending announcements
//

import SwiftUI
import CloudKit

struct AnnouncementComposerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared

    @State private var title = ""
    @State private var message = ""
    @State private var category: Announcement.Category = .general
    @State private var priority: Announcement.Priority = .medium
    @State private var isCritical = false
    @State private var isPinned = false
    @State private var expiryDays = 7

    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section("Announcement Details") {
                    TextField("Title", text: $title)
                        .font(.headline)

                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text("Type your announcement here...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(Announcement.Category.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.displayName)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Announcement.Priority.allCases, id: \.self) { pri in
                            Text(pri.displayName).tag(pri)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Settings") {
                    Toggle(isOn: $isPinned) {
                        HStack {
                            Image(systemName: "pin.fill")
                            Text("Pin to top")
                        }
                    }

                    Toggle(isOn: $isCritical) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("Critical Alert")
                                Text("Bypasses Do Not Disturb")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.red)

                    Picker("Expires in", selection: $expiryDays) {
                        Text("1 day").tag(1)
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                }

                if isCritical {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.red)
                            Text("Use critical alerts sparingly for emergencies, safety alerts, or urgent schedule changes only.")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
            .navigationTitle("New Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sendAnnouncement()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .bold()
                        }
                    }
                    .disabled(!canSend || isSending)
                }
            }
            .alert("Announcement Sent!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your announcement has been published successfully.")
            }
        }
    }

    var canSend: Bool {
        !title.isEmpty && !message.isEmpty && preferences.isAdmin
    }

    private func sendAnnouncement() {
        guard canSend else { return }

        isSending = true
        errorMessage = nil

        let announcement = Announcement(
            title: title,
            body: message,
            expiryDate: Date().addingTimeInterval(TimeInterval(expiryDays * 24 * 60 * 60)),
            priority: priority,
            category: category,
            author: preferences.userName.isEmpty ? "Admin" : preferences.userName,
            isPinned: isPinned,
            isCritical: isCritical
        )

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase
                let record = announcement.toRecord()
                try await database.save(record)

                // Send critical alert if marked as critical
                if isCritical {
                    await sendCriticalNotification(for: announcement)
                }

                await MainActor.run {
                    isSending = false
                    showingSuccess = true
                    print("✅ Announcement published: \(announcement.title)")
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send: \(error.localizedDescription)"
                    isSending = false
                }
            }
        }
    }

    private func sendCriticalNotification(for announcement: Announcement) async {
        // Request critical alert authorization
        let center = UNUserNotificationCenter.current()

        do {
            // Request authorization with critical alert option
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .criticalAlert])

            guard granted else {
                print("⚠️ Critical alert authorization not granted")
                return
            }

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = announcement.title
            content.body = announcement.body
            content.categoryIdentifier = announcement.category.rawValue

            // Mark as critical alert (bypasses Do Not Disturb)
            content.interruptionLevel = .critical
            content.sound = .defaultCritical

            // Add badge
            content.badge = 1

            // Trigger immediately
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: announcement.id,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
            print("✅ Critical alert scheduled: \(announcement.title)")

        } catch {
            print("❌ Error sending critical alert: \(error.localizedDescription)")
        }
    }
}

#Preview {
    AnnouncementComposerView()
}
