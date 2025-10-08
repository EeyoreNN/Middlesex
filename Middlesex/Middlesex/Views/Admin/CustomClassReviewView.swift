//
//  CustomClassReviewView.swift
//  Middlesex
//
//  Admin view to review user-submitted custom classes
//

import SwiftUI
import CloudKit

struct CustomClassReviewView: View {
    @Environment(\.dismiss) var dismiss
    @State private var customClasses: [CustomClass] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading submissions...")
                } else if customClasses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Custom Classes")
                            .font(.headline)
                        Text("User-submitted classes will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(customClasses) { customClass in
                            CustomClassRow(
                                customClass: customClass,
                                onApprove: { approveClass(customClass) },
                                onDelete: { deleteClass(customClass) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Custom Class Submissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await fetchCustomClasses()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await fetchCustomClasses()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func fetchCustomClasses() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let database = CKContainer.default().publicCloudDatabase
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "CustomClass", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "submittedAt", ascending: false)]

            let results = try await database.records(matching: query)

            let classes = results.matchResults.compactMap { _, result -> CustomClass? in
                guard let record = try? result.get() else { return nil }
                return CustomClass(from: record)
            }

            await MainActor.run {
                self.customClasses = classes
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load custom classes: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func approveClass(_ customClass: CustomClass) {
        Task {
            do {
                let database = CKContainer.default().publicCloudDatabase

                // Find and update the record
                let predicate = NSPredicate(format: "id == %@", customClass.id)
                let query = CKQuery(recordType: "CustomClass", predicate: predicate)

                let results = try await database.records(matching: query)
                if let recordResult = results.matchResults.first?.1,
                   let record = try? recordResult.get() {
                    record["isApproved"] = 1 as CKRecordValue
                    try await database.save(record)

                    await fetchCustomClasses()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to approve class: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func deleteClass(_ customClass: CustomClass) {
        Task {
            do {
                let database = CKContainer.default().publicCloudDatabase

                // Find and delete the record
                let predicate = NSPredicate(format: "id == %@", customClass.id)
                let query = CKQuery(recordType: "CustomClass", predicate: predicate)

                let results = try await database.records(matching: query)
                if let recordResult = results.matchResults.first?.1,
                   let record = try? recordResult.get() {
                    _ = try await database.deleteRecord(withID: record.recordID)

                    await fetchCustomClasses()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete class: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct CustomClassRow: View {
    let customClass: CustomClass
    let onApprove: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(customClass.className)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label(customClass.teacherName, systemImage: "person.fill")
                            .font(.subheadline)
                        Label(customClass.roomNumber, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)

                    Text(customClass.department)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Spacer()

                if customClass.isApproved {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }

            HStack(spacing: 4) {
                Text("Submitted by:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(customClass.submittedBy)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(customClass.submittedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !customClass.isApproved {
                HStack(spacing: 12) {
                    Button {
                        onApprove()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(8)
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CustomClassReviewView()
}
