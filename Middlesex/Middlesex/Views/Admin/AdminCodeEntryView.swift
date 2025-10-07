//
//  AdminCodeEntryView.swift
//  Middlesex
//
//  Admin code entry and generation for Nick Noon
//

import SwiftUI
import CloudKit

struct AdminCodeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared
    @State private var enteredCode = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var generatedCode: AdminCode?
    @State private var showingGeneratedCode = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                // Admin icon
                Image(systemName: "key.fill")
                    .font(.system(size: 80))
                    .foregroundColor(MiddlesexTheme.primaryRed)

                Text("Admin Access")
                    .font(.largeTitle.bold())
                    .foregroundColor(MiddlesexTheme.textPrimary)

                // Show code generator for Nick Noon
                if preferences.userName == "Nick Noon" {
                    VStack(spacing: 20) {
                        Button {
                            generateCode()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate Admin Code")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(MiddlesexTheme.primaryRed)
                            .cornerRadius(12)
                        }

                        if let code = generatedCode {
                            VStack(spacing: 12) {
                                Text("Generated Code:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(code.code)
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                                    .foregroundColor(MiddlesexTheme.primaryRed)
                                    .padding()
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(12)

                                Text("Expires in 2 hours")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button {
                                    UIPasteboard.general.string = code.code
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Code")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(MiddlesexTheme.primaryRed)
                                }
                            }
                        }

                        Divider()
                            .padding(.vertical)
                    }
                }

                // Code entry
                VStack(spacing: 16) {
                    Text("Enter admin code to claim access")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Enter 8-digit code", text: $enteredCode)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2.monospacedDigit())
                        .disabled(isValidating)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        claimAdminAccess()
                    } label: {
                        if isValidating {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Claim Admin Access")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(enteredCode.count == 8 ? MiddlesexTheme.primaryRed : Color.gray)
                    .cornerRadius(12)
                    .disabled(enteredCode.count != 8 || isValidating)
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateCode() {
        let code = AdminCode.create(generatedBy: preferences.userName)
        generatedCode = code

        // Save to CloudKit
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase
                print("💾 Saving code to CloudKit (public database): \(code.code)")
                let savedRecord = try await database.save(code.toRecord())
                print("✅ Admin code saved successfully: \(code.code)")
                print("📝 Record ID: \(savedRecord.recordID.recordName)")
            } catch {
                print("❌ Failed to save admin code: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        }
    }

    private func claimAdminAccess() {
        guard enteredCode.count == 8 else {
            errorMessage = "Code must be 8 digits"
            return
        }

        isValidating = true
        errorMessage = nil
        print("🔍 Validating code: \(enteredCode)")

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase
                print("📦 Using container (public database): \(container.containerIdentifier ?? "default")")

                // Query for the code
                print("🔍 Searching for code: \(enteredCode)")

                // First check if any AdminCode records exist
                let allPredicate = NSPredicate(value: true)
                let allQuery = CKQuery(recordType: "AdminCode", predicate: allPredicate)
                let allResults = try await database.records(matching: allQuery)
                print("📊 Total AdminCode records: \(allResults.matchResults.count)")

                // Now search for specific code
                let predicate = NSPredicate(format: "code == %@", enteredCode)
                let query = CKQuery(recordType: "AdminCode", predicate: predicate)
                let results = try await database.records(matching: query)
                print("📊 Found \(results.matchResults.count) results for '\(enteredCode)'")

                guard let record = try results.matchResults.first?.1.get() else {
                    await MainActor.run {
                        print("❌ No matching code found in CloudKit")
                        errorMessage = "Invalid code (not found in database)"
                        isValidating = false
                    }
                    return
                }

                // Validate code
                guard let adminCode = AdminCode(record: record) else {
                    await MainActor.run {
                        errorMessage = "Invalid code format"
                        isValidating = false
                    }
                    return
                }

                if !adminCode.isValid {
                    await MainActor.run {
                        errorMessage = "Code expired"
                        isValidating = false
                    }
                    return
                }

                // Grant admin access (code is valid and not expired)
                await MainActor.run {
                    preferences.isAdmin = true
                    isValidating = false
                    dismiss()
                }

                print("✅ Admin access granted to \(preferences.userName)")

            } catch {
                await MainActor.run {
                    print("❌ CloudKit error: \(error)")
                    errorMessage = "Error: \(error.localizedDescription)"
                    isValidating = false
                }
            }
        }
    }
}

#Preview {
    AdminCodeEntryView()
}
