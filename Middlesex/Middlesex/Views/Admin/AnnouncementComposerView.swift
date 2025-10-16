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
    @StateObject private var cloudKitManager = CloudKitManager.shared

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
        guard canSend else {
            print("⚠️ Cannot send - validation failed")
            return
        }

        isSending = true
        errorMessage = nil
        print("📤 Starting announcement send...")

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

        print("📋 Announcement created: \(announcement.title)")

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase
                print("📦 Using container: \(container.containerIdentifier ?? "unknown")")

                let record = announcement.toRecord()
                print("💾 Saving announcement to CloudKit...")
                try await database.save(record)
                print("✅ Saved to CloudKit successfully")

                // Send critical alert if marked as critical
                if isCritical {
                    print("🚨 Sending critical notification...")
                    await sendCriticalNotification(for: announcement)
                }

                // Refresh announcements list
                print("🔄 Refreshing announcements list...")
                await cloudKitManager.fetchActiveAnnouncements()
                print("📊 Announcements count after refresh: \(cloudKitManager.announcements.count)")

                await MainActor.run {
                    isSending = false
                    showingSuccess = true
                    print("✅ Announcement published: \(announcement.title)")
                }

            } catch {
                await MainActor.run {
                    print("❌ Failed to send announcement: \(error)")
                    errorMessage = "Failed to send: \(error.localizedDescription)"
                    isSending = false
                }
            }
        }
    }

    private func sendCriticalNotification(for announcement: Announcement) async {
        print("🚨 Sending critical alert via NotificationManager...")
        await NotificationManager.shared.sendCriticalAlert(
            title: announcement.title,
            body: announcement.body,
            sound: .defaultCritical
        )
        print("✅ Critical alert sent: \(announcement.title)")
    }
}

#Preview {
    AnnouncementComposerView()
}
