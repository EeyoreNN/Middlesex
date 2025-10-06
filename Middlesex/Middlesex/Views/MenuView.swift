//
//  MenuView.swift
//  Middlesex
//
//  Daily menu display
//

import SwiftUI

struct MenuView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var selectedDate = Date()
    @State private var selectedMealType: MenuItem.MealType = .lunch

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date picker
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color.white)

                // Meal type selector
                Picker("Meal Type", selection: $selectedMealType) {
                    ForEach(MenuItem.MealType.allCases, id: \.self) { mealType in
                        Text(mealType.displayName).tag(mealType)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Menu items
                if cloudKitManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMenuItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No menu available")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Check back later for today's menu")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(MenuItem.MenuCategory.allCases, id: \.self) { category in
                                let items = filteredMenuItems.filter { $0.category == category }
                                if !items.isEmpty {
                                    MenuCategorySection(category: category, items: items)
                                }
                            }

                            Spacer(minLength: 80)
                        }
                        .padding()
                    }
                }
            }
            .background(MiddlesexTheme.background)
            .navigationTitle("Menu")
            .onChange(of: selectedDate) {
                Task {
                    await cloudKitManager.fetchMenuItems(for: selectedDate, mealType: selectedMealType)
                }
            }
            .onChange(of: selectedMealType) {
                Task {
                    await cloudKitManager.fetchMenuItems(for: selectedDate, mealType: selectedMealType)
                }
            }
            .task {
                await cloudKitManager.fetchMenuItems(for: selectedDate, mealType: selectedMealType)
            }
        }
    }

    private var filteredMenuItems: [MenuItem] {
        cloudKitManager.menuItems.filter { $0.mealType == selectedMealType }
    }
}

struct MenuCategorySection: View {
    let category: MenuItem.MenuCategory
    let items: [MenuItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.displayName)
                .font(.headline)
                .foregroundColor(MiddlesexTheme.primaryRed)

            ForEach(items) { item in
                MenuItemCard(item: item)
            }
        }
    }
}

struct MenuItemCard: View {
    let item: MenuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    if item.isVegan {
                        Label("Vegan", systemImage: "leaf.fill")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else if item.isVegetarian {
                        Label("Vegetarian", systemImage: "leaf")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }

            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !item.allergens.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Text("Contains: \(item.allergens.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    MenuView()
}
