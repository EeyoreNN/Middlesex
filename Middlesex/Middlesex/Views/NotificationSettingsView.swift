//
//  NotificationSettingsView.swift
//  Middlesex
//
//  Notification preferences settings
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var notificationsEnabled = false
    @State private var showingPermissionAlert = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationsEnabled ? MiddlesexTheme.primaryRed : .gray)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications")
                                .font(.headline)
                            Text(notificationsEnabled ? "Enabled" : "Disabled in Settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !notificationsEnabled {
                            Button("Enable") {
                                openSettings()
                            }
                            .font(.subheadline)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Status")
                } footer: {
                    if !notificationsEnabled {
                        Text("To receive notifications, enable them in Settings > Notifications > Middlesex")
                    }
                }

                Section {
                    Toggle(isOn: $preferences.notificationsNextClass) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Next Class", systemImage: "bell.badge")
                                .font(.headline)
                            Text("Get notified when your current class ends about your next class")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(MiddlesexTheme.primaryRed)
                    .disabled(!notificationsEnabled)

                    Toggle(isOn: $preferences.notificationsSportsUpdates) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Sports Updates", systemImage: "sportscourt")
                                .font(.headline)
                            Text("Get score updates and game reminders for followed teams")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(MiddlesexTheme.primaryRed)
                    .disabled(!notificationsEnabled)

                    Toggle(isOn: $preferences.notificationsAnnouncements) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Announcements", systemImage: "megaphone")
                                .font(.headline)
                            Text("Get notified when new school announcements are posted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(MiddlesexTheme.primaryRed)
                    .disabled(!notificationsEnabled)
                } header: {
                    Text("Notification Types")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(MiddlesexTheme.primaryRed)
                }
            }
            .onAppear {
                checkNotificationStatus()
            }
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NotificationSettingsView()
}
