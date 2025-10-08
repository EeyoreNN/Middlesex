//
//  AdminDashboardView.swift
//  Middlesex
//
//  Admin control panel for managing school data
//

import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared

    @State private var showingAnnouncementComposer = false
    @State private var showingSpecialScheduleBuilder = false
    @State private var showingLunchMenuImport = false
    @State private var showingSportsImport = false
    @State private var showingAdminCodeEntry = false
    @State private var showingAPISettings = false
    @State private var showingCustomClassReview = false

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
        }
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
