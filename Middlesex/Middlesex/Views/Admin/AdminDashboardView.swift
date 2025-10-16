//
//  AdminDashboardView.swift
//  Middlesex
//
//  Admin control panel for managing school data
//

import SwiftUI
import CloudKit

struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var preferences = UserPreferences.shared

    @State private var showingAnnouncementComposer = false
    @State private var showingSpecialScheduleBuilder = false
    @State private var showingLunchMenuImport = false
    @State private var showingSportsImport = false
    @State private var showingAdminCodeEntry = false
    @State private var showingAPISettings = false
    @State private var showingCustomClassReview = false
    @State private var showingPermanentAdminTools = false

    var body: some View {
        NavigationView {
            List {
                Section("Announcements") {
                    Button {
                        showingAnnouncementComposer = true
                    } label: {
                        Label("Create Announcement", systemImage: "megaphone.fill")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                }

                Section("Schedule Management") {
                    Button {
                        showingSpecialScheduleBuilder = true
                    } label: {
                        Label("Create Special Schedule", systemImage: "calendar.badge.plus")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                }

                Section("Data Import") {
                    Button {
                        showingLunchMenuImport = true
                    } label: {
                        Label("Import Lunch Menu", systemImage: "fork.knife")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }

                    Button {
                        showingSportsImport = true
                    } label: {
                        Label("Import Sports Schedule", systemImage: "figure.run")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                }

                Section("User Submissions") {
                    Button {
                        showingCustomClassReview = true
                    } label: {
                        Label("Review Custom Classes", systemImage: "list.clipboard")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }

                    Button {
                        Task {
                            await createTestCustomClasses()
                        }
                    } label: {
                        Label("Create 3 Test Custom Classes", systemImage: "plus.circle")
                            .foregroundColor(.orange)
                    }
                }

                Section("Testing Tools") {
                    Button {
                        Task {
                            await createTestUsers()
                        }
                    } label: {
                        Label("Check/Setup Test Users", systemImage: "person.3.fill")
                            .foregroundColor(.green)
                    }

                    Button {
                        Task {
                            await forceSyncUserData()
                        }
                    } label: {
                        Label("Force Sync My Data to CloudKit", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    }
                }

                Section("Settings") {
                    Button {
                        showingAPISettings = true
                    } label: {
                        Label("API Configuration", systemImage: "gear")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }

                    Button {
                        showingAdminCodeEntry = true
                    } label: {
                        Label("Manage Admin Codes", systemImage: "key.fill")
                            .foregroundColor(MiddlesexTheme.primaryRed)
                    }
                }

                if cloudKitManager.isCurrentUserPermanentAdmin() {
                    Section("Permanent Admin Tools") {
                        Button {
                            showingPermanentAdminTools = true
                        } label: {
                            Label("Permanent Admin Management", systemImage: "shield.lefthalf.filled")
                                .foregroundColor(MiddlesexTheme.primaryRed)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        preferences.isAdmin = false
                        dismiss()
                    } label: {
                        Label("Revoke Admin Access", systemImage: "xmark.shield.fill")
                    }
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAnnouncementComposer) {
                AnnouncementComposerView()
            }
            .sheet(isPresented: $showingSpecialScheduleBuilder) {
                SpecialScheduleBuilderView()
            }
            .sheet(isPresented: $showingLunchMenuImport) {
                LunchMenuImportView()
            }
            .sheet(isPresented: $showingSportsImport) {
                SportsScheduleImportView()
            }
            .sheet(isPresented: $showingAdminCodeEntry) {
                AdminCodeEntryView()
            }
            .sheet(isPresented: $showingAPISettings) {
                APISettingsView()
            }
            .sheet(isPresented: $showingCustomClassReview) {
                CustomClassReviewView()
            }
            .sheet(isPresented: $showingPermanentAdminTools) {
                PermanentAdminManagementView()
            }
        }
        .task {
            await cloudKitManager.refreshPermanentAdmins()
        }
    }

    private func createTestCustomClasses() async {
        let testClasses = [
            CustomClass(
                className: "Advanced Robotics",
                teacherName: "Dr. Smith",
                roomNumber: "SCI-101",
                department: "Science",
                submittedBy: "Test User 1",
                isApproved: false
            ),
            CustomClass(
                className: "Creative Writing Workshop",
                teacherName: "Ms. Johnson",
                roomNumber: "ENG-205",
                department: "English",
                submittedBy: "Test User 2",
                isApproved: false
            ),
            CustomClass(
                className: "Digital Music Production",
                teacherName: "Mr. Williams",
                roomNumber: "ART-310",
                department: "Arts",
                submittedBy: "Test User 3",
                isApproved: false
            )
        ]

        let database = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex").publicCloudDatabase

        print("🧪 Creating 3 test CustomClass records...")

        for customClass in testClasses {
            do {
                let record = customClass.toRecord()
                try await database.save(record)
                print("✅ Created test class: \(customClass.className) (recordID: \(record.recordID.recordName))")
            } catch {
                print("❌ Failed to create test class \(customClass.className): \(error.localizedDescription)")
            }
        }

        print("🧪 Test data creation complete!")
    }

    private func createTestUsers() async {
        let database = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex").publicCloudDatabase

        print("🔍 Checking for existing UserPreferences records in CloudKit...")

        do {
            // Query all UserPreferences records to see what exists
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "UserPreferences", predicate: predicate)
            let results = try await database.records(matching: query)

            print("📊 Found \(results.matchResults.count) existing UserPreferences records:")

            var existingUsers: [(userId: String, userName: String?, userGrade: String?)] = []
            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    let userId = record["userId"] as? String ?? "unknown"
                    let userName = record["userName"] as? String
                    let userGrade = record["userGrade"] as? String
                    existingUsers.append((userId, userName, userGrade))
                    print("   - userId: \(userId)")
                    print("     userName: \(userName ?? "(not set)")")
                    print("     userGrade: \(userGrade ?? "(not set)")")
                }
            }

            // Try to update the current user's record with a test name
            let currentUserId = UserPreferences.shared.userIdentifier
            if !currentUserId.isEmpty {
                print("\n💡 Attempting to update your own UserPreferences record...")
                print("   Your userId: \(currentUserId)")

                // Check if current user already has a record
                let userPredicate = NSPredicate(format: "userId == %@", currentUserId)
                let userQuery = CKQuery(recordType: "UserPreferences", predicate: userPredicate)
                let userResults = try await database.records(matching: userQuery)

                if let existingResult = userResults.matchResults.first,
                   let existingRecord = try? existingResult.1.get() {
                    // Record exists, try to update it
                    let currentName = existingRecord["userName"] as? String ?? ""
                    if currentName.isEmpty {
                        existingRecord["userName"] = "Test Admin User" as CKRecordValue
                        existingRecord["userGrade"] = "Faculty" as CKRecordValue
                        existingRecord["updatedAt"] = Date() as CKRecordValue

                        try await database.save(existingRecord)
                        print("✅ Updated your UserPreferences with test name: 'Test Admin User'")
                        print("💡 Now open the announcement composer to test!")
                    } else {
                        print("✅ Your record already has a name: '\(currentName)'")
                        print("💡 This name will appear in the announcement composer!")
                    }
                } else {
                    print("⚠️ No UserPreferences record found for your userId")
                    print("💡 The app should create one automatically when you save settings")
                }
            }

            if existingUsers.isEmpty {
                print("\n⚠️ No UserPreferences records found in CloudKit!")
                print("💡 Suggestions:")
                print("   1. Make sure users have opened the app and set their names in Settings")
                print("   2. Use the manual entry option in the announcement composer")
                print("   3. Check CloudKit Dashboard to see if records exist")
            } else {
                let namedUsers = existingUsers.filter { $0.userName != nil && !$0.userName!.isEmpty }
                print("\n✅ Found \(namedUsers.count) users with names set")
                print("💡 These users will appear in the announcement composer autocomplete!")
            }

        } catch {
            print("❌ Error querying UserPreferences: \(error.localizedDescription)")
        }
    }

    private func forceSyncUserData() async {
        print("🔄 Force syncing user data to CloudKit...")
        print("   userId: \(preferences.userIdentifier)")
        print("   userName: \(preferences.userName)")
        print("   userGrade: \(preferences.userGrade)")

        guard !preferences.userIdentifier.isEmpty else {
            print("❌ Cannot sync - no userIdentifier set!")
            return
        }

        await cloudKitManager.saveUserData(
            userId: preferences.userIdentifier,
            userName: preferences.userName,
            userGrade: preferences.userGrade,
            prefersCelsius: preferences.prefersCelsius,
            notificationsNextClass: preferences.notificationsNextClass,
            notificationsSportsUpdates: preferences.notificationsSportsUpdates,
            notificationsAnnouncements: preferences.notificationsAnnouncements
        )

        print("✅ Force sync complete!")
        print("💡 Now run 'Check/Setup Test Users' to verify your data is in CloudKit")
    }
}

struct APISettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var apiKey = ""
    @State private var showingSaved = false
    @State private var isTesting = false
    @State private var testResult = ""
    @State private var showTestResult = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("OpenAI API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                } header: {
                    Text("OpenAI Configuration")
                } footer: {
                    Text("This API key is used for AI-powered schedule import from photos. Get your key at platform.openai.com")
                }

                Section {
                    Button {
                        OpenAIVisionAPI.shared.setAPIKey(apiKey)
                        showingSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(showingSaved ? "Saved!" : "Save API Key")
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(MiddlesexTheme.primaryRed)
                    .disabled(apiKey.isEmpty)
                }

                Section {
                    Button {
                        Task {
                            await testAPIConnection()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                                Text("Testing...")
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.white)
                                Text("Test API Connection")
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                    .disabled(isTesting)
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Tests the API key using a simple GPT-3.5 request. Check console logs for detailed output.")
                }
            }
            .navigationTitle("API Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isTesting ? "Testing..." : "Test Result", isPresented: $showTestResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(testResult)
            }
        }
    }

    private func testAPIConnection() async {
        isTesting = true
        defer { isTesting = false }

        do {
            let response = try await OpenAIVisionAPI.shared.testAPIKey()
            await MainActor.run {
                testResult = "✅ Success!\n\nAPI Response: \(response)\n\nCheck console logs for detailed debugging info."
                showTestResult = true
            }
        } catch {
            await MainActor.run {
                testResult = "❌ Test Failed\n\n\(error.localizedDescription)\n\nCheck console logs for detailed debugging info."
                showTestResult = true
            }
        }
    }
}

#Preview {
    AdminDashboardView()
}
