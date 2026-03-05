//
//  HomeView.swift
//  Middlesex
//
//  Home/Dashboard view accessed via center logo button
//

import SwiftUI
import WeatherKit

struct HomeView: View {
    @StateObject private var preferences = UserPreferences.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var weatherManager = CampusWeatherManager.shared
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    @State private var showingAdminCodeEntry = false
    @State private var showingAnnouncementComposer = false
    @State private var showingAdminDashboard = false
    @State private var showingGuestClassesFlow = false
    @State private var showingNotificationSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back,")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text(preferences.userName.isEmpty ? "Student" : preferences.userName)
                            .font(.largeTitle.bold())
                            .foregroundColor(MiddlesexTheme.textPrimary)

                        if !preferences.userGrade.isEmpty {
                            Text(preferences.userGrade)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Campus Weather Card
                    CampusWeatherCard(weatherManager: weatherManager)
                        .padding(.horizontal)

                    // Admin tools
                    if preferences.isAdmin {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Admin Tools")
                                    .font(.headline)
                                    .foregroundColor(MiddlesexTheme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal)

                            Button {
                                showingAdminDashboard = true
                            } label: {
                                HStack {
                                    Image(systemName: "gear.circle.fill")
                                    Text("Admin Dashboard")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(MiddlesexTheme.primaryRed)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        #if DEBUG
                        // Dev tools (admin only, debug builds)
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "wrench.fill")
                                    .foregroundColor(.gray)
                                Text("Developer Tools")
                                    .font(.headline)
                                    .foregroundColor(MiddlesexTheme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            devToolButton("Admin Code Entry", icon: "key.fill", color: .red) {
                                showingAdminCodeEntry = true
                            }

                            devToolButton("Reset Onboarding", icon: "arrow.clockwise.circle.fill", color: .orange) {
                                preferences.clearAllData()
                            }

                            devToolButton("Test Update Flow", icon: "sparkles", color: .purple) {
                                preferences.onboardingVersion = 1
                            }

                            devToolButton("Test Live Activity", icon: "bell.badge.fill", color: .blue) {
                                if #available(iOS 16.2, *) {
                                    testLiveActivity()
                                }
                            }

                            devToolButton("Admin Mode: \(preferences.isAdmin ? "ON" : "OFF")", icon: preferences.isAdmin ? "checkmark.circle.fill" : "circle", color: preferences.isAdmin ? .green : .gray) {
                                preferences.isAdmin.toggle()
                            }

                            devToolButton("Guest Classes", icon: "person.badge.plus.fill", color: .teal) {
                                showingGuestClassesFlow = true
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        #endif
                    }

                    // Quick stats
                    HStack(spacing: 12) {
                        QuickStatCard(
                            icon: "calendar",
                            title: "Schedule",
                            value: getCurrentWeekType(),
                            color: getCurrentWeekType() == "Red Week" ? MiddlesexTheme.redWeekColor : MiddlesexTheme.whiteWeekColor
                        )

                        QuickStatCard(
                            icon: "megaphone.fill",
                            title: "Announcements",
                            value: "\(cloudKitManager.announcements.count)",
                            color: MiddlesexTheme.primaryRed
                        )
                    }
                    .padding(.horizontal)

                    // Notification settings button
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(MiddlesexTheme.primaryRed)
                            Text("Notification Settings")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(MiddlesexTheme.cardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Today's info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        // Live current class view
                        CurrentClassLiveView()
                            .padding(.horizontal)

                        // Recent announcements
                        if !cloudKitManager.announcements.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Latest Announcements")
                                        .font(.headline)
                                    Spacer()
                                    NavigationLink("See All") {
                                        // Link to announcements tab
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(MiddlesexTheme.primaryRed)
                                }
                                .padding(.horizontal)

                                ForEach(cloudKitManager.announcements.prefix(3)) { announcement in
                                    AnnouncementRowCompact(announcement: announcement)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top)
            }
            .background(MiddlesexTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: handleLogoTap) {
                        Image(systemName: "shield.fill")
                            .font(.title3)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingAdminCodeEntry) {
                AdminCodeEntryView()
            }
            .sheet(isPresented: $showingAnnouncementComposer) {
                AnnouncementComposerView()
            }
            .sheet(isPresented: $showingAdminDashboard) {
                AdminDashboardView()
            }
            .sheet(isPresented: $showingGuestClassesFlow) {
                GuestClassesFlow()
            }
            .task {
                await weatherManager.fetchWeather()
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
        }
    }

    #if DEBUG
    private func devToolButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    #endif

    private func handleLogoTap() {
        let now = Date()

        // Reset if more than 3 seconds since last tap
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) > 3 {
            tapCount = 0
        }

        tapCount += 1
        lastTapTime = now

        print("🔔 Logo tap \(tapCount)/10")

        // After 10 taps determine admin flow
        if tapCount >= 10 {
            if preferences.isAdmin {
                print("✅ Already admin - opening dashboard")
                showingAdminDashboard = true
            } else if preferences.hasPermanentAdminAccess {
                print("✅ Permanent admin detected - restoring admin access without code entry")
                preferences.isAdmin = true
                showingAdminDashboard = true
            } else {
                print("✅ Opening admin code entry!")
                showingAdminCodeEntry = true
            }
            tapCount = 0
        }
    }

    private func getCurrentWeekType() -> String {
        // Simple alternating week logic - you can make this more sophisticated
        let weekNumber = Calendar.current.component(.weekOfYear, from: Date())
        return weekNumber % 2 == 0 ? "Red Week" : "White Week"
    }

    private func getNextClass() -> (class: UserClass, period: Int, time: PeriodTime)? {
        let weekType: ClassSchedule.WeekType = getCurrentWeekType() == "Red Week" ? .red : .white
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        // Simple logic to find next period
        for periodTime in PeriodTime.defaultSchedule where currentHour < 15 {
            if let userClass = preferences.getClassWithFallback(for: periodTime.period, preferredWeekType: weekType) {
                return (userClass, periodTime.period, periodTime)
            }
        }
        return nil
    }

    #if DEBUG
    @available(iOS 16.2, *)
    private func testLiveActivity() {
        let now = Date()
        let endDate = now.addingTimeInterval(40 * 60)

        LiveActivityManager.shared.startClassActivity(
            className: "AP Calculus BC",
            teacher: "Mr. Smith",
            room: "Math 101",
            block: "A",
            startTime: "8:25",
            endTime: "9:05",
            classColor: "#1E90FF",
            startDate: now,
            endDate: endDate
        )
    }
    #endif
}

struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(MiddlesexTheme.textPrimary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct NextClassCard: View {
    let userClass: UserClass
    let period: Int
    let periodTime: PeriodTime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(MiddlesexTheme.primaryRed)
                Text("Next Class")
                    .font(.headline)
            }

            HStack(spacing: 16) {
                VStack {
                    Text("\(period)")
                        .font(.title.bold())
                        .foregroundColor(Color(hex: userClass.color) ?? MiddlesexTheme.primaryRed)

                    Text(periodTime.startTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(userClass.className)
                        .font(.headline)

                    Text(userClass.teacher)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Room \(userClass.room)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: userClass.color)?.opacity(0.1) ?? MiddlesexTheme.primaryRed.opacity(0.1), Color.white],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: userClass.color)?.opacity(0.3) ?? MiddlesexTheme.primaryRed.opacity(0.3), lineWidth: 1)
        )
    }
}

struct AnnouncementRowCompact: View {
    let announcement: Announcement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: announcement.category.icon)
                .font(.title3)
                .foregroundColor(MiddlesexTheme.primaryRed)
                .frame(width: 40, height: 40)
                .background(MiddlesexTheme.primaryRed.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(announcement.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text(announcement.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    HomeView()
}
