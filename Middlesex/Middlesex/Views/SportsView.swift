//
//  SportsView.swift
//  Middlesex
//
//  Sports schedules, scores, and team information
//

import SwiftUI

struct SportsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var selectedTab: SportsTab = .upcoming

    enum SportsTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case results = "Results"
        case teams = "Teams"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Sports Tab", selection: $selectedTab) {
                    ForEach(SportsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                Group {
                    switch selectedTab {
                    case .upcoming:
                        UpcomingEventsView()
                    case .results:
                        ResultsView()
                    case .teams:
                        TeamsView()
                    }
                }
            }
            .background(MiddlesexTheme.background)
            .navigationTitle("Sports")
            .refreshable {
                await refreshData()
            }
        }
    }

    private func refreshData() async {
        switch selectedTab {
        case .upcoming:
            await cloudKitManager.fetchUpcomingSportsEvents()
        case .results:
            await cloudKitManager.fetchRecentSportsResults()
        case .teams:
            await cloudKitManager.fetchActiveTeams()
        }
    }
}

struct UpcomingEventsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some View {
        Group {
            if cloudKitManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cloudKitManager.sportsEvents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No upcoming events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(cloudKitManager.sportsEvents) { event in
                            SportsEventCard(event: event)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding()
                }
            }
        }
        .task {
            await cloudKitManager.fetchUpcomingSportsEvents()
        }
    }
}

struct ResultsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some View {
        Group {
            if cloudKitManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cloudKitManager.sportsEvents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No recent results")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(cloudKitManager.sportsEvents) { event in
                            SportsResultCard(event: event)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding()
                }
            }
        }
        .task {
            await cloudKitManager.fetchRecentSportsResults()
        }
    }
}

struct TeamsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some View {
        Group {
            if cloudKitManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cloudKitManager.sportsTeams.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No active teams")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(cloudKitManager.sportsTeams) { team in
                            TeamCard(team: team)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding()
                }
            }
        }
        .task {
            await cloudKitManager.fetchActiveTeams()
        }
    }
}

struct SportsEventCard: View {
    let event: SportsEvent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: event.sport.icon)
                    .font(.title3)
                    .foregroundColor(MiddlesexTheme.primaryRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.sport.rawValue)
                        .font(.headline)

                    Text(event.eventType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.eventDate, style: .date)
                        .font(.subheadline)

                    Text(event.eventDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(MiddlesexTheme.primaryRed.opacity(0.1))

            // Details
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Middlesex")
                            .font(.headline)

                        Text(event.isHome ? "Home" : "Away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("vs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(event.opponent)
                            .font(.headline)

                        Text(event.isHome ? "Away" : "Home")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    Label(event.location, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding()
        }
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct SportsResultCard: View {
    let event: SportsEvent

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: event.sport.icon)
                    .font(.title3)
                    .foregroundColor(MiddlesexTheme.primaryRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.sport.rawValue)
                        .font(.headline)

                    Text(event.eventDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let result = event.result {
                    Text(result)
                        .font(.headline)
                        .foregroundColor(resultColor(for: event))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(resultColor(for: event).opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(resultColor(for: event).opacity(0.1))

            // Score
            HStack {
                VStack(spacing: 8) {
                    Text("Middlesex")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(event.middlesexScore)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(MiddlesexTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)

                Text("-")
                    .font(.title)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text(event.opponent)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(event.opponentScore)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(MiddlesexTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func resultColor(for event: SportsEvent) -> Color {
        guard event.middlesexScore >= 0, event.opponentScore >= 0 else {
            return .gray
        }

        if event.middlesexScore > event.opponentScore {
            return .green
        } else if event.middlesexScore < event.opponentScore {
            return .red
        } else {
            return .orange
        }
    }
}

struct TeamCard: View {
    let team: SportsTeam

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: team.sport.icon)
                    .font(.title2)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                    .frame(width: 50, height: 50)
                    .background(MiddlesexTheme.primaryRed.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.teamName)
                        .font(.headline)

                    Text("\(team.season.displayName) \(team.year)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(team.record)
                        .font(.title3.bold())
                        .foregroundColor(MiddlesexTheme.primaryRed)

                    Text("Record")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(team.coachName)
                        .font(.subheadline)
                }

                Spacer()

                if !team.captains.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Captain\(team.captains.count > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(team.captains.first ?? "")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    SportsView()
}
