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
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var isFollowLoading = false
    @State private var isClaimLoading = false
    @State private var alertMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            details
        }
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .alert(alertMessage ?? "", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
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
        .background(MiddlesexTheme.primaryRed.opacity(0.12))
    }

    @ViewBuilder
    private var details: some View {
        VStack(spacing: 16) {
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

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(event.location, systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(statusText())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let result = event.result {
                    Text(result)
                        .font(.headline)
                        .foregroundColor(resultColor(for: event))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(resultColor(for: event).opacity(0.12))
                        .cornerRadius(8)
                }
            }

            if #available(iOS 16.2, *) {
                SportsLiveControlsView(
                    event: event,
                    isFollowLoading: $isFollowLoading,
                    isClaimLoading: $isClaimLoading,
                    alertMessage: $alertMessage,
                    userPreferences: userPreferences
                )
            }
        }
        .padding()
    }

    private func statusText() -> String {
        let now = Date()
        switch event.status {
        case .scheduled:
            if now < event.eventDate {
                let minutes = Int(event.eventDate.timeIntervalSince(now) / 60)
                if minutes <= 60 {
                    return "Starts in \(minutes)m"
                }
                return "Starts at \(event.eventDate.formatted(date: .omitted, time: .shortened))"
            } else {
                return "In progress"
            }
        case .inProgress:
            return "In progress"
        case .completed:
            return "Final"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func resultColor(for event: SportsEvent) -> Color {
        guard let result = event.result else { return .secondary }
        if result.starts(with: "W") {
            return .green
        } else if result.starts(with: "L") {
            return .red
        } else {
            return .orange
        }
    }
}

@available(iOS 16.2, *)
struct SportsLiveControlsView: View {
    let event: SportsEvent
    @Binding var isFollowLoading: Bool
    @Binding var isClaimLoading: Bool
    @Binding var alertMessage: String?
    let userPreferences: UserPreferences

    @StateObject private var liveActivityManager = SportsLiveActivityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    toggleFollow()
                } label: {
                    Label(isFollowing ? "Stop Live Updates" : "Follow Live Updates",
                          systemImage: isFollowing ? "dot.radiowaves.left.and.right.slash" : "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .controlSize(.small)
                .disabled(isFollowLoading || !supportsLiveActivity)
                .overlay {
                    if isFollowLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }

                if canClaimButtonVisible {
                    claimButton
                }
            }

            if !supportsLiveActivity {
                Text("Live Activities currently available for Soccer, Football, and Cross Country.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let claim = liveActivityManager.activeClaims[event.id] {
                claimStatusView(claim)
            }
        }
        .task {
            await liveActivityManager.fetchActiveClaim(eventId: event.id)
        }
    }

    private var isFollowing: Bool {
        liveActivityManager.isFollowing(eventId: event.id)
    }

    private var supportsLiveActivity: Bool {
        SportsActivityAttributes.SportType(eventSport: event.sport) != nil
    }

    private var canClaimButtonVisible: Bool {
        guard supportsLiveActivity else { return false }
        guard event.status != .cancelled else { return false }
        return isWithinClaimWindow || reporterClaimIsMine
    }

    private var reporterClaimIsMine: Bool {
        guard let claim = liveActivityManager.activeClaims[event.id] else { return false }
        return claim.reporterId == userPreferences.userIdentifier && claim.status == .active
    }

    private var isWithinClaimWindow: Bool {
        let windowStart = event.eventDate.addingTimeInterval(-3600)
        let windowEnd = event.eventDate.addingTimeInterval(3600)
        let now = Date()
        return now >= windowStart && now <= windowEnd
    }

    private func toggleFollow() {
        guard supportsLiveActivity else {
            alertMessage = "Live Activities currently support Soccer, Football, and Cross Country."
            return
        }

        isFollowLoading = true

        Task {
            do {
                if isFollowing {
                    await liveActivityManager.stopFollowing(eventId: event.id, userPreferences: userPreferences)
                } else {
                    try await liveActivityManager.follow(event: event, userPreferences: userPreferences)
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isFollowLoading = false
            }
        }
    }

    @ViewBuilder
    private var claimButton: some View {
        Button {
            handleClaimAction()
        } label: {
            Label(
                reporterClaimIsMine ? "Release Reporter Spot" : "Claim Reporter Spot",
                systemImage: reporterClaimIsMine ? "person.crop.circle.badge.minus" : "person.badge.plus"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isClaimLoading || claimDisabledForCurrentUser)
        .overlay {
            if isClaimLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
    }

    private var claimDisabledForCurrentUser: Bool {
        guard let claim = liveActivityManager.activeClaims[event.id] else { return false }
        if claim.reporterId == userPreferences.userIdentifier {
            return false
        }
        return true
    }

    private func handleClaimAction() {
        guard userPreferences.isSignedIn else {
            alertMessage = "Sign in to claim the reporter role."
            return
        }

        guard supportsLiveActivity else {
            alertMessage = "Live Activities currently support Soccer, Football, and Cross Country."
            return
        }

        isClaimLoading = true

        Task {
            do {
                if reporterClaimIsMine {
                    await liveActivityManager.releaseReporter(eventId: event.id)
                } else {
                    guard isWithinClaimWindow else {
                        await MainActor.run {
                            alertMessage = "Reporter signups open one hour before the game and close one hour after it starts."
                            isClaimLoading = false
                        }
                        return
                    }

                    _ = try await liveActivityManager.claimReporter(
                        for: event,
                        reporterId: userPreferences.userIdentifier,
                        reporterName: userPreferences.userName.isEmpty ? "Reporter" : userPreferences.userName
                    )
                }
            } catch SportsLiveCloudKitService.ServiceError.reporterAlreadyClaimed(let name) {
                await MainActor.run {
                    alertMessage = "\(name) is currently reporting this game."
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                if isClaimLoading {
                    isClaimLoading = false
                }
            }
        }
    }

    @ViewBuilder
    private func claimStatusView(_ claim: SportsReporterClaim) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if claim.reporterId == userPreferences.userIdentifier {
                Text("You are reporting this game.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Reporter: \(claim.reporterName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Claim expires \(claim.expiresAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
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
