//
//  AnnouncementsView.swift
//  Middlesex
//
//  School announcements view
//

import SwiftUI

struct AnnouncementsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var selectedCategory: Announcement.Category?
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search announcements", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(MiddlesexTheme.secondaryGray)
                .cornerRadius(10)
                .padding()

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterChip(
                            category: nil,
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(Announcement.Category.allCases, id: \.self) { category in
                            CategoryFilterChip(
                                category: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)

                // Announcements list
                if cloudKitManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredAnnouncements.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No announcements")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Check back later for updates")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredAnnouncements) { announcement in
                                NavigationLink {
                                    AnnouncementDetailView(announcement: announcement)
                                } label: {
                                    AnnouncementCard(announcement: announcement)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer(minLength: 80)
                        }
                        .padding()
                    }
                }
            }
            .background(MiddlesexTheme.background)
            .navigationTitle("Announcements")
            .refreshable {
                await cloudKitManager.fetchActiveAnnouncements()
            }
        }
    }

    private var filteredAnnouncements: [Announcement] {
        var announcements = cloudKitManager.announcements

        // Filter by category
        if let category = selectedCategory {
            announcements = announcements.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            announcements = announcements.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort: pinned first, then by date
        return announcements.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.publishDate > rhs.publishDate
        }
    }
}

struct CategoryFilterChip: View {
    let category: Announcement.Category?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                }

                Text(category?.displayName ?? "All")
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? MiddlesexTheme.primaryRed : Color.white)
            .foregroundColor(isSelected ? .white : MiddlesexTheme.textDark)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct AnnouncementCard: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: announcement.category.icon)
                    .font(.title3)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                    .frame(width: 40, height: 40)
                    .background(MiddlesexTheme.primaryRed.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if announcement.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundColor(MiddlesexTheme.primaryRed)
                        }

                        Text(announcement.title)
                            .font(.headline)
                            .foregroundColor(MiddlesexTheme.textPrimary)
                    }

                    HStack {
                        Text(announcement.category.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor(announcement.priority).opacity(0.2))
                            .foregroundColor(priorityColor(announcement.priority))
                            .cornerRadius(4)

                        Text(announcement.publishDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(announcement.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func priorityColor(_ priority: Announcement.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

struct AnnouncementDetailView: View {
    let announcement: Announcement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: announcement.category.icon)
                            .font(.title)
                            .foregroundColor(MiddlesexTheme.primaryRed)

                        Text(announcement.category.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        if announcement.isPinned {
                            Label("Pinned", systemImage: "pin.fill")
                                .font(.caption)
                                .foregroundColor(MiddlesexTheme.primaryRed)
                        }
                    }

                    Text(announcement.title)
                        .font(.title.bold())

                    HStack {
                        Text("Posted by \(announcement.author)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(announcement.publishDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Body
                Text(announcement.body)
                    .font(.body)
                    .lineSpacing(6)

                if let imageURL = announcement.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
        }
        .background(MiddlesexTheme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AnnouncementsView()
}
