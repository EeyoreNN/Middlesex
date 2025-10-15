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
                                onApprove: { approveClass(customClass) }
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
            let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
            let database = container.publicCloudDatabase

            print("🔍 Fetching from CloudKit container: \(container.containerIdentifier ?? "unknown")")
            print("📊 Database: publicCloudDatabase")

            // First, get ALL records to see what's actually there
            print("🔍 Fetching ALL CustomClass records from CloudKit...")
            let allPredicate = NSPredicate(value: true)
            let allQuery = CKQuery(recordType: "CustomClass", predicate: allPredicate)
            allQuery.sortDescriptors = [NSSortDescriptor(key: "submittedAt", ascending: false)]

            let allResults = try await database.records(matching: allQuery)
            print("📊 Found \(allResults.matchResults.count) total CustomClass records")

            // Now filter for unapproved classes
            let classes = allResults.matchResults.compactMap { _, result -> CustomClass? in
                guard let record = try? result.get() else {
                    print("⚠️ Failed to get record from result")
                    return nil
                }

                let isApproved = (record["isApproved"] as? Int64) ?? 0
                let className = record["className"] as? String ?? "unknown"

                print("   📝 Record: \(className) - isApproved: \(isApproved)")

                // Only include unapproved classes
                guard isApproved == 0 else {
                    print("      ⏭️ Skipping approved class")
                    return nil
                }

                let customClass = CustomClass(from: record)
                if let customClass = customClass {
                    print("✅ Loaded unapproved class: \(customClass.className) (recordID: \(record.recordID.recordName))")
                }
                return customClass
            }

            await MainActor.run {
                self.customClasses = classes
                print("📋 Total unapproved classes loaded: \(classes.count)")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load custom classes: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func listAllRecords(in database: CKDatabase, label: String) async {
        print("📋 \(label) - Listing ALL CustomClass records:")
        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "CustomClass", predicate: predicate)
            let results = try await database.records(matching: query)

            print("   Found \(results.matchResults.count) total records")
            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    let className = record["className"] as? String ?? "nil"
                    let teacherName = record["teacherName"] as? String ?? "nil"
                    let roomNumber = record["roomNumber"] as? String ?? "nil"
                    let isApproved = record["isApproved"] as? Int64 ?? -1
                    print("   📝 \(record.recordID.recordName): '\(className)' / '\(teacherName)' / '\(roomNumber)' / approved:\(isApproved)")
                }
            }
        } catch {
            print("   ❌ Failed to list records: \(error.localizedDescription)")
        }
    }

    private func approveClass(_ customClass: CustomClass) {
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase

                print("🔍 Approve using container: \(container.containerIdentifier ?? "unknown")")
                print("📊 Database: publicCloudDatabase")

                // List all records BEFORE approval
                await listAllRecords(in: database, label: "BEFORE APPROVAL")

                // Approve the class
                try await approveClass(recordID: customClass.recordID, customClass: customClass, in: database)

                // List all records AFTER approval
                await listAllRecords(in: database, label: "AFTER APPROVAL")

                // Only refresh after successful approval
                await MainActor.run {
                    // Remove from local list immediately for responsive UI
                    self.customClasses.removeAll { $0.id == customClass.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to approve class: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }


    private func approveClass(recordID: CKRecord.ID?, customClass: CustomClass, in database: CKDatabase) async throws {
        print("🔍 Starting approval for: \(customClass.className)")
        print("   recordID: \(recordID?.recordName ?? "nil")")
        print("   className: '\(customClass.className)'")
        print("   teacher: '\(customClass.teacherName)'")
        print("   room: '\(customClass.roomNumber)'")

        // If we have a recordID, try using it
        if let recordID = recordID {
            do {
                print("📡 Fetching record by ID...")
                let record = try await database.record(for: recordID)
                print("✅ Got record, setting isApproved = 1")
                record["isApproved"] = 1 as CKRecordValue
                print("💾 Saving record...")
                try await database.save(record)
                print("✅ Successfully approved!")
                return
            } catch let error as CKError {
                print("❌ Failed to fetch by recordID: \(error.localizedDescription)")
                print("   Error code: \(error.code.rawValue)")
            } catch {
                print("❌ Unknown error: \(error)")
            }
        }

        // RecordID didn't work, try finding by unique fields
        print("🔄 Trying query-based lookup...")
        try await approveClassByQuery(customClass, in: database)
    }

    private func approveClassByQuery(_ customClass: CustomClass, in database: CKDatabase) async throws {
        print("🔍 Building query for unapproved class matching fields...")

        let predicate = NSPredicate(
            format: "className == %@ AND teacherName == %@ AND roomNumber == %@ AND isApproved == %d",
            customClass.className,
            customClass.teacherName,
            customClass.roomNumber,
            0
        )
        let query = CKQuery(recordType: "CustomClass", predicate: predicate)

        print("📡 Executing query...")
        let results = try await database.records(matching: query)
        print("📊 Query returned \(results.matchResults.count) results")

        guard let recordResult = results.matchResults.first?.1,
              let record = try? recordResult.get() else {
            print("❌ No matching record found")
            throw NSError(
                domain: "CustomClassReviewView",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Could not find the custom class record in CloudKit. It may have been deleted by another admin."]
            )
        }

        print("✅ Found record via query: \(record.recordID.recordName)")
        print("💾 Setting isApproved = 1 and saving...")
        record["isApproved"] = 1 as CKRecordValue
        try await database.save(record)
        print("✅ Successfully approved!")
    }

}

struct CustomClassRow: View {
    let customClass: CustomClass
    let onApprove: () -> Void

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
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CustomClassReviewView()
}
