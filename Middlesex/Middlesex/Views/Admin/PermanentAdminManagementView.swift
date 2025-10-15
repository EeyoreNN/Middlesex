//
//  PermanentAdminManagementView.swift
//  Middlesex
//
//  Tools reserved for permanent administrators: custom code generation and admin management.
//

import SwiftUI
import UIKit

struct PermanentAdminManagementView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var preferences = UserPreferences.shared

    @State private var codeType: AdminCode.CodeType = .temporary
    @State private var durationHours: Int = AdminCode.CodeType.temporary.defaultDurationMinutes / 60
    @State private var customCode = ""
    @State private var latestGeneratedCode: AdminCode?
    @State private var isGeneratingCode = false
    @State private var generationError: String?

    @State private var adminPendingRemoval: PermanentAdmin?
    @State private var showRemovalConfirmation = false
    @State private var removalError: String?
    @State private var deletingAdminID: String?

    private let durationRange = 1...168 // 1 hour to 7 days

    var body: some View {
        NavigationView {
            Form {
                Section("Custom Code Generation") {
                    Picker("Access Level", selection: $codeType) {
                        ForEach(AdminCode.CodeType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: codeType) { _, newValue in
                        durationHours = max(
                            durationRange.lowerBound,
                            min(durationRange.upperBound, newValue.defaultDurationMinutes / 60)
                        )
                    }

                    Stepper(
                        value: $durationHours,
                        in: durationRange,
                        step: 1
                    ) {
                        Text("Code expires after \(durationHours) hour\(durationHours == 1 ? "" : "s")")
                    }

                    TextField("Optional 8-digit custom code", text: $customCode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)

                    if let error = generationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        generateCustomCode()
                    } label: {
                        HStack {
                            if isGeneratingCode {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text(isGeneratingCode ? "Generating..." : "Generate Code")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isGeneratingCode)
                }

                if let code = latestGeneratedCode {
                    Section("Generated Code") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(code.code)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(MiddlesexTheme.primaryRed)

                            Text("Type: \(code.type.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Expires: \(formatted(date: code.expiresAt))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button {
                                UIPasteboard.general.string = code.code
                            } label: {
                                Label("Copy Code", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Permanent Administrators") {
                    if cloudKitManager.permanentAdmins.isEmpty {
                        Text("No permanent admins yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(cloudKitManager.permanentAdmins) { admin in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(admin.displayName ?? "Unknown User")
                                        .font(.headline)
                                    Text(admin.userId)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if admin.userId != preferences.userIdentifier {
                                    Button(role: .destructive) {
                                        adminPendingRemoval = admin
                                        showRemovalConfirmation = true
                                    } label: {
                                        if deletingAdminID == admin.id {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                        } else {
                                            Text("Remove")
                                        }
                                    }
                                } else {
                                    Text("You")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if let error = removalError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Permanent Admin Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Remove permanent admin?",
                isPresented: $showRemovalConfirmation,
                presenting: adminPendingRemoval
            ) { admin in
                Button("Remove \(admin.displayName ?? admin.userId)", role: .destructive) {
                    remove(admin)
                }
            } message: { admin in
                Text("This revokes permanent access for \(admin.displayName ?? admin.userId). They will need a new code to regain admin rights.")
            }
            .task {
                await cloudKitManager.refreshPermanentAdmins(force: true)
            }
        }
    }

    private func generateCustomCode() {
        guard !isGeneratingCode else { return }
        generationError = nil

        let trimmed = customCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !isValidCustomCode(trimmed) {
            generationError = "Custom code must be exactly 8 digits."
            return
        }

        isGeneratingCode = true
        let generatorId = preferences.userIdentifier.isEmpty ? preferences.userName : preferences.userIdentifier
        let durationMinutes = durationHours * 60

        Task {
            do {
                let adminCode: AdminCode
                if codeType == .permanent {
                    adminCode = AdminCode.createPermanent(
                        generatedBy: generatorId,
                        durationMinutes: durationMinutes,
                        code: trimmed.isEmpty ? nil : trimmed
                    )
                } else {
                    adminCode = AdminCode.createTemporary(
                        generatedBy: generatorId,
                        durationMinutes: durationMinutes,
                        code: trimmed.isEmpty ? nil : trimmed
                    )
                }

                try await cloudKitManager.saveAdminCode(adminCode)

                await MainActor.run {
                    latestGeneratedCode = adminCode
                    customCode = ""
                }
            } catch {
                await MainActor.run {
                    generationError = "Failed to save code: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                isGeneratingCode = false
            }
        }
    }

    private func remove(_ admin: PermanentAdmin) {
        guard deletingAdminID == nil else { return }
        deletingAdminID = admin.id
        removalError = nil

        Task {
            do {
                try await cloudKitManager.removePermanentAdmin(admin)
                await cloudKitManager.refreshPermanentAdmins(force: true)
            } catch {
                await MainActor.run {
                    removalError = "Failed to remove admin: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                deletingAdminID = nil
            }
        }
    }

    private func isValidCustomCode(_ value: String) -> Bool {
        let digitsOnly = CharacterSet.decimalDigits
        return value.count == 8 && CharacterSet(charactersIn: value).isSubset(of: digitsOnly)
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    PermanentAdminManagementView()
}
