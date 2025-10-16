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
    @State private var specificUserNames = "" // Comma-separated names (deprecated, kept for compatibility)
    @State private var selectedUsers: [String] = [] // Array of selected user names
    @State private var userSearchText = "" // Search text for filtering users
    @State private var availableUsers: [String] = [] // All users from CloudKit
    @State private var isLoadingUsers = false
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
                        VStack(alignment: .leading, spacing: 12) {
                            // Info message if no users available
                            if availableUsers.isEmpty && !isLoadingUsers {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.orange)
                                    Text("No users found in CloudKit. Make sure users have set their names in UserPreferences.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // Search field
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search for users...", text: $userSearchText)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                                    .disabled(availableUsers.isEmpty && !isLoadingUsers)

                                if isLoadingUsers {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }

                                if !userSearchText.isEmpty {
                                    Button {
                                        userSearchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(8)
                            .opacity(availableUsers.isEmpty && !isLoadingUsers ? 0.5 : 1.0)

                            // Selected users chips
                            if !selectedUsers.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(selectedUsers, id: \.self) { user in
                                            HStack(spacing: 6) {
                                                Text(user)
                                                    .font(.subheadline)

                                                Button {
                                                    selectedUsers.removeAll { $0 == user }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.caption)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(MiddlesexTheme.primaryRed.opacity(0.15))
                                            .foregroundColor(MiddlesexTheme.primaryRed)
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                            }

                            // Filtered user suggestions
                            if !userSearchText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(filteredUsers, id: \.self) { user in
                                        Button {
                                            if !selectedUsers.contains(user) {
                                                selectedUsers.append(user)
                                                userSearchText = ""
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "person.circle.fill")
                                                    .foregroundColor(MiddlesexTheme.primaryRed)
                                                Text(user)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if selectedUsers.contains(user) {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(MiddlesexTheme.primaryRed)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color(UIColor.secondarySystemFill))
                                            .cornerRadius(8)
                                        }
                                    }

                                    if filteredUsers.isEmpty && !availableUsers.isEmpty {
                                        HStack {
                                            Image(systemName: "person.slash")
                                                .foregroundColor(.secondary)
                                            Text("No users found")
                                                .foregroundColor(.secondary)
                                        }
                                        .font(.subheadline)
                                        .padding(.vertical, 8)
                                    }

                                    // Manual entry option
                                    if filteredUsers.isEmpty || availableUsers.isEmpty {
                                        Button {
                                            let trimmedText = userSearchText.trimmingCharacters(in: .whitespaces)
                                            if !trimmedText.isEmpty && !selectedUsers.contains(trimmedText) {
                                                selectedUsers.append(trimmedText)
                                                userSearchText = ""
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(.green)
                                                Text("Add \"\(userSearchText)\" manually")
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            Text("Selected: \(selectedUsers.count) user\(selectedUsers.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
            .task {
                await fetchAvailableUsers()
            }
        }
    }

    var filteredUsers: [String] {
        guard !userSearchText.isEmpty else { return [] }

        return availableUsers.filter { user in
            user.localizedCaseInsensitiveContains(userSearchText)
        }
        .sorted()
        .prefix(10) // Limit to 10 suggestions
        .map { $0 }
    }

    var canSend: Bool {
        guard !title.isEmpty && !message.isEmpty && preferences.isAdmin else {
            return false
        }

        // If targeting specific people, require at least one selected user
        if targetAudience == .specific && selectedUsers.isEmpty {
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

        // Use selected users if audience is .specific
        let targetUserNames: [String]? = targetAudience == .specific && !selectedUsers.isEmpty
            ? selectedUsers
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

                // Push notifications are handled automatically via CloudKit subscriptions
                // When this announcement is saved, CloudKit will send a silent push to all subscribed users
                if sendPushNotification {
                    print("📡 CloudKit will send push notifications to all subscribed users")
                    if isCritical {
                        print("   Note: Critical alerts are sent through CloudKit subscriptions")
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

    private func fetchAvailableUsers() async {
        await MainActor.run {
            isLoadingUsers = true
        }

        do {
            let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
            let database = container.publicCloudDatabase

            print("👥 Fetching users from CloudKit...")

            // Query UserPreferences records to get all user names
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "UserPreferences", predicate: predicate)
            // Sort in code instead of CloudKit to avoid schema requirements

            let results = try await database.records(matching: query)

            print("📊 Found \(results.matchResults.count) UserPreferences records")

            let users = results.matchResults.compactMap { _, result -> String? in
                guard let record = try? result.get() else {
                    print("⚠️ Failed to get record from result")
                    return nil
                }

                let userName = record["userName"] as? String
                let userId = record["userId"] as? String
                print("   Record - userId: \(userId ?? "nil"), userName: \(userName ?? "nil")")

                guard let name = userName, !name.isEmpty else {
                    return nil
                }
                return name
            }

            // Remove duplicates and sort (case-insensitive sort for better UX)
            let uniqueUsers = Array(Set(users)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

            await MainActor.run {
                self.availableUsers = uniqueUsers
                self.isLoadingUsers = false
                print("✅ Loaded \(uniqueUsers.count) users for autocomplete")
                print("   Users: \(uniqueUsers.joined(separator: ", "))")
                if uniqueUsers.isEmpty {
                    print("⚠️ No users with names found! UserPreferences may have empty userName fields")
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingUsers = false
                print("❌ Failed to fetch users: \(error.localizedDescription)")
                print("   Full error: \(error)")
            }
        }
    }
}

#Preview {
    AnnouncementComposerView()
}
