//
//  HomeView.swift
//  Middlesex
//
//  Home/Dashboard view accessed via center logo button
//

import SwiftUI

struct HomeView: View {
    @StateObject private var preferences = UserPreferences.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    @State private var showingAdminCodeEntry = false
    @State private var showingAnnouncementComposer = false

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
                            .foregroundColor(MiddlesexTheme.textDark)

                        if !preferences.userGrade.isEmpty {
                            Text(preferences.userGrade)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Admin tools
                    if preferences.isAdmin {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Admin Tools")
                                    .font(.headline)
                                    .foregroundColor(MiddlesexTheme.textDark)
                                Spacer()
                            }
                            .padding(.horizontal)

                            Button {
                                showingAnnouncementComposer = true
                            } label: {
                                HStack {
                                    Image(systemName: "megaphone.fill")
                                    Text("Create Announcement")
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
                    }

                    // TEMPORARY: Dev tools
                    VStack(spacing: 8) {
                        Button {
                            showingAdminCodeEntry = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Admin Code Entry (Dev Only)")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                        }

                        Button {
                            preferences.clearAllData()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                Text("Reset Onboarding (Dev Only)")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                        }

                        Button {
                            // Simulate old version to test update flow
                            preferences.onboardingVersion = 1
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Test Update Flow (Dev Only)")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                        }

                        Button {
                            // Test Live Activity
                            if #available(iOS 16.2, *) {
                                testLiveActivity()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                Text("Test Live Activity (Dev Only)")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

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
                        Image(systemName: "building.columns.fill")
                            .font(.title3)
                            .foregroundColor(MiddlesexTheme.primaryRed)
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
        }
    }

    private func handleLogoTap() {
        let now = Date()

        // Reset if more than 3 seconds since last tap
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) > 3 {
            tapCount = 0
        }

        tapCount += 1
        lastTapTime = now

        print("🔔 Logo tap \(tapCount)/10")

        // Show admin code entry after 10 taps
        if tapCount >= 10 {
            print("✅ Opening admin code entry!")
            showingAdminCodeEntry = true
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
        for periodTime in PeriodTime.defaultSchedule {
            if currentHour < 15 { // Before 3 PM
                if let userClass = preferences.getClass(for: periodTime.period, weekType: weekType) {
                    return (userClass, periodTime.period, periodTime)
                }
            }
        }
        return nil
    }

    @available(iOS 16.2, *)
    private func testLiveActivity() {
        // Create a test Live Activity for AP Calculus BC class
        let now = Date()
        let endDate = now.addingTimeInterval(40 * 60) // 40 minutes from now

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

        print("🧪 Test Live Activity started!")
    }
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
                    .foregroundColor(MiddlesexTheme.textDark)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
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
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    HomeView()
}
