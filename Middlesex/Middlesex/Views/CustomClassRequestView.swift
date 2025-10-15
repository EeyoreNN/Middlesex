//
//  CustomClassRequestView.swift
//  Middlesex
//
//  User interface for requesting custom classes
//

import SwiftUI
import CloudKit

struct CustomClassRequestView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared

    @State private var className = ""
    @State private var teacherName = ""
    @State private var roomNumber = ""
    @State private var selectedDepartment: ClassDepartment = .other

    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Class Name", text: $className)
                        .autocapitalization(.words)

                    TextField("Teacher Name", text: $teacherName)
                        .autocapitalization(.words)

                    TextField("Room Number", text: $roomNumber)
                        .autocapitalization(.allCharacters)

                    Picker("Department", selection: $selectedDepartment) {
                        ForEach(ClassDepartment.allCases, id: \.self) { department in
                            HStack {
                                Image(systemName: department.icon)
                                Text(department.rawValue)
                            }
                            .tag(department)
                        }
                    }
                } header: {
                    Text("Class Information")
                } footer: {
                    Text("Your submission will be reviewed by administrators and added to the app if approved.")
                }

                Section {
                    Button {
                        Task {
                            await submitCustomClass()
                        }
                    } label: {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Submitting...")
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Submit Request")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .listRowBackground(MiddlesexTheme.primaryRed)
                    .disabled(isSubmitting || className.isEmpty || teacherName.isEmpty || roomNumber.isEmpty)
                }
            }
            .navigationTitle("Request Custom Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your custom class request has been submitted for review. You'll be notified when it's approved.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitCustomClass() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let customClass = CustomClass(
                className: className,
                teacherName: teacherName,
                roomNumber: roomNumber,
                department: selectedDepartment.rawValue,
                submittedBy: preferences.userName.isEmpty ? "Anonymous" : preferences.userName,
                isApproved: false
            )

            let database = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex").publicCloudDatabase
            let record = customClass.toRecord()

            print("📤 Submitting CustomClass to CloudKit:")
            print("   className: \(customClass.className)")
            print("   teacher: \(customClass.teacherName)")
            print("   room: \(customClass.roomNumber)")
            print("   recordID: \(record.recordID.recordName)")

            try await database.save(record)
            print("✅ Successfully saved CustomClass record")

            await MainActor.run {
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to submit request: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    CustomClassRequestView()
}
