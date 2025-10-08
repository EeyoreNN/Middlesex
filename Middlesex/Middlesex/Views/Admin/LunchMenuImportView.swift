//
//  LunchMenuImportView.swift
//  Middlesex
//
//  Admin tool for importing lunch menu data
//

import SwiftUI
import CloudKit

struct LunchMenuImportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = UserPreferences.shared

    @State private var menuDate = Date()
    @State private var mealType: MenuItem.MealType = .lunch
    @State private var menuItems: [MenuItem] = []
    @State private var showingAddItem = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section("Menu Information") {
                    DatePicker("Date", selection: $menuDate, displayedComponents: .date)

                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MenuItem.MealType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Menu Items") {
                    ForEach(menuItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            if !item.description.isEmpty {
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                if item.isVegetarian {
                                    Label("Vegetarian", systemImage: "leaf.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                if item.isVegan {
                                    Label("Vegan", systemImage: "leaf.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        menuItems.remove(atOffsets: indexSet)
                    }

                    Button {
                        showingAddItem = true
                    } label: {
                        Label("Add Menu Item", systemImage: "plus.circle.fill")
                            .foregroundColor(MiddlesexTheme.primaryRed)
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
            .navigationTitle("Import Lunch Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMenu()
                    }
                    .disabled(menuItems.isEmpty || isSaving)
                }

                ToolbarItem(placement: .principal) {
                    if isSaving {
                        ProgressView()
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddMenuItemSheet(menuItems: $menuItems, menuDate: menuDate, mealType: mealType)
            }
            .alert("Menu Saved!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The lunch menu has been saved successfully.")
            }
        }
    }

    private func saveMenu() {
        guard !menuItems.isEmpty else {
            errorMessage = "Please add at least one menu item"
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.nicholasnoon.Middlesex")
                let database = container.publicCloudDatabase

                // Save all menu items
                for item in menuItems {
                    let record = item.toRecord()
                    try await database.save(record)
                }

                await MainActor.run {
                    isSaving = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

struct AddMenuItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var menuItems: [MenuItem]
    let menuDate: Date
    let mealType: MenuItem.MealType

    @State private var title = ""
    @State private var description = ""
    @State private var category: MenuItem.MenuCategory = .main
    @State private var allergens = ""
    @State private var isVegetarian = false
    @State private var isVegan = false

    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $title)
                    TextField("Description (optional)", text: $description)
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(MenuItem.MenuCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section("Dietary Information") {
                    Toggle("Vegetarian", isOn: $isVegetarian)
                    Toggle("Vegan", isOn: $isVegan)
                    TextField("Allergens (comma-separated)", text: $allergens)
                }
            }
            .navigationTitle("Add Menu Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func addItem() {
        let allergenArray = allergens.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

        let item = MenuItem(
            date: menuDate,
            mealType: mealType,
            title: title,
            description: description,
            category: category,
            allergens: allergenArray,
            isVegetarian: isVegetarian,
            isVegan: isVegan
        )

        menuItems.append(item)
        dismiss()
    }
}

#Preview {
    LunchMenuImportView()
}
