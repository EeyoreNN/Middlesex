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
    @State private var targetAudience: Announcement.TargetAudience = .everyone
    @State private var specificUserNames = "" // Comma-separated names
    @State private var sendPushNotification = false
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

                Section("Target Audience") {
                    Picker("Send to", selection: $targetAudience) {
                        ForEach(Announcement.TargetAudience.allCases, id: \.self) { audience in
                            HStack {
                                Image(systemName: audience.icon)
                                Text(audience.displayName)
                            }
                            .tag(audience)
                        }
                    }
                    .pickerStyle(.menu)

                    if targetAudience == .specific {
                        TextField("Enter names (comma-separated)", text: $specificUserNames)
                            .textContentType(.name)
                            .autocapitalization(.words)

                        Text("Enter names separated by commas. Example: John Smith, Jane Doe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Settings") {
                    Toggle(isOn: $isPinned) {
                        HStack {
                            Image(systemName: "pin.fill")
                            Text("Pin to top")
                        }
                    }

                    Toggle(isOn: $sendPushNotification) {
                        HStack {
                            Image(systemName: "bell.fill")
                            VStack(alignment: .leading) {
                                Text("Send Push Notification")
                                Text("Alert users with a notification")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if sendPushNotification {
                        Toggle(isOn: $isCritical) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Make it Critical")
                                    Text("Bypasses Do Not Disturb & Focus modes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .tint(.red)
                    }

                    Picker("Expires in", selection: $expiryDays) {
                        Text("1 day").tag(1)
                        Text("3 days").tag(3)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                    }
                }

                if sendPushNotification && isCritical {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.red)
                            Text("Critical alerts bypass Do Not Disturb. Use only for emergencies, safety alerts, or urgent schedule changes.")
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
        guard !title.isEmpty && !message.isEmpty && preferences.isAdmin else {
            return false
        }

        // If targeting specific people, require at least one name
        if targetAudience == .specific && specificUserNames.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }

        return true
    }

    private func sendAnnouncement() {
        guard canSend else {
            print("⚠️ Cannot send - validation failed")
            return
        }

        isSending = true
        errorMessage = nil
        print("📤 Starting announcement send...")

        // Parse specific user names if audience is .specific
        let targetUserNames: [String]? = targetAudience == .specific && !specificUserNames.isEmpty
            ? specificUserNames.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            : nil

        let announcement = Announcement(
            title: title,
            body: message,
            expiryDate: Date().addingTimeInterval(TimeInterval(expiryDays * 24 * 60 * 60)),
            priority: priority,
            category: category,
            author: preferences.userName.isEmpty ? "Admin" : preferences.userName,
            isPinned: isPinned,
            isCritical: isCritical,
            targetAudience: targetAudience,
            targetUserNames: targetUserNames
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

                // Send push notification if enabled
                if sendPushNotification {
                    if isCritical {
                        print("🚨 Sending critical notification...")
                        await sendCriticalNotification(for: announcement)
                    } else {
                        print("🔔 Sending regular notification...")
                        await sendRegularNotification(for: announcement)
                    }
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

    private func sendRegularNotification(for announcement: Announcement) async {
        print("🔔 Sending regular notification via NotificationManager...")
        await NotificationManager.shared.sendNotification(
            title: announcement.title,
            body: announcement.body,
            category: announcement.category.rawValue.uppercased()
        )
        print("✅ Regular notification sent: \(announcement.title)")
    }
}

#Preview {
    AnnouncementComposerView()
}
