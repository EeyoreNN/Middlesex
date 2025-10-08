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
    @State private var selectedEvent: SportsEvent?

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
                            SportsEventCard(
                                event: event,
                                onSelect: { selectedEvent = event }
                            )
                        }

                        Spacer(minLength: 80)
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            SportsEventDetailView(event: event)
                .environmentObject(cloudKitManager)
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
    var onSelect: (() -> Void)? = nil
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var isFollowLoading = false
    @State private var isClaimLoading = false
    @State private var alertMessage: String?
    @State private var showingReporterConsole = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            details
        }
        .background(MiddlesexTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .sheet(isPresented: $showingReporterConsole) {
            ReporterConsoleView(event: event)
        }
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
                    userPreferences: userPreferences,
                    onStartReporting: {
                        showingReporterConsole = true
                    }
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

struct SportsEventDetailView: View {
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(\.dismiss) private var dismiss

    let event: SportsEvent

    @State private var isFollowLoading = false
    @State private var isClaimLoading = false
    @State private var alertMessage: String?
    @State private var showingReporterConsole = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    infoSection
                    actionSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(event.opponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert(alertMessage ?? "", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showingReporterConsole) {
            ReporterConsoleView(event: event)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: event.sport.icon)
                    .font(.largeTitle)
                    .foregroundColor(MiddlesexTheme.primaryRed)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.sport.rawValue)
                        .font(.title3.bold())
                    Text(event.eventType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                Label(event.eventDate.formatted(date: .long, time: .omitted), systemImage: "calendar")
                Label(event.eventDate.formatted(date: .omitted, time: .shortened), systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch event.status {
            case .scheduled:
                Text("Scheduled")
                    .font(.headline)
            case .inProgress:
                Text("In Progress")
                    .font(.headline)
                    .foregroundColor(.orange)
            case .completed:
                if let result = event.result {
                    Text(result)
                        .font(.headline)
                        .foregroundColor(result.hasPrefix("W") ? .green : result.hasPrefix("L") ? .red : .orange)
                } else {
                    Text("Final")
                        .font(.headline)
                }
            case .cancelled:
                Text("Cancelled")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(event.location, systemImage: "mappin.and.ellipse")
                Label(event.isHome ? "Home Game" : "Away Game", systemImage: event.isHome ? "house.fill" : "road.lanes")
                Label("Season: \(event.season.displayName)", systemImage: "leaf")
                Label("Year: \(event.year)", systemImage: "calendar.circle")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            if !event.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(event.notes)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var actionSection: some View {
        Group {
            if #available(iOS 16.2, *) {
                SportsLiveControlsView(
                    event: event,
                    isFollowLoading: $isFollowLoading,
                    isClaimLoading: $isClaimLoading,
                    alertMessage: $alertMessage,
                    userPreferences: userPreferences,
                    onStartReporting: { showingReporterConsole = true }
                )
            } else {
                Text("Live Activities require iOS 16.2 or later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    var onStartReporting: (() -> Void)? = nil

    @StateObject private var liveActivityManager = SportsLiveActivityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                followButton

                if reporterClaimIsMine {
                    startReportingButton
                } else if shouldShowClaimButton {
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

            if reporterClaimIsMine {
                surrenderButton
            }
        }
        .task {
            await liveActivityManager.fetchActiveClaim(eventId: event.id)
        }
    }

    private var followButton: some View {
        Button {
            toggleFollow()
        } label: {
            Label(isFollowing ? "Stop Live Updates" : "Follow Live Updates",
                  systemImage: isFollowing ? "dot.radiowaves.left.and.right" : "dot.radiowaves.right")
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .controlSize(.small)
        .disabled(isFollowLoading || !supportsLiveActivity)
        .overlay(alignment: .center) {
            if isFollowLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
    }

    private var startReportingButton: some View {
        Button {
            triggerStartReporting()
        } label: {
            Label("Start Reporting", systemImage: "pencil.and.outline")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isClaimLoading)
    }

    private var claimButton: some View {
        Button {
            handleClaimAction()
        } label: {
            Label("Claim Reporter Spot", systemImage: "person.badge.plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isClaimLoading || claimDisabledForCurrentUser)
        .overlay(alignment: .center) {
            if isClaimLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
    }

    private var surrenderButton: some View {
        Button(role: .destructive) {
            surrenderReportingSpot()
        } label: {
            Label("Surrender Reporting Spot", systemImage: "person.crop.circle.badge.minus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isClaimLoading)
        .overlay(alignment: .center) {
            if isClaimLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
    }

    private var isFollowing: Bool {
        liveActivityManager.isFollowing(eventId: event.id)
    }

    private var supportsLiveActivity: Bool {
        SportsActivityAttributes.SportType(eventSport: event.sport) != nil
    }

    private var reporterClaimIsMine: Bool {
        guard let claim = liveActivityManager.activeClaims[event.id] else { return false }
        return claim.reporterId == userPreferences.userIdentifier && claim.status == .active
    }

    private var shouldShowClaimButton: Bool {
        guard supportsLiveActivity else { return false }
        guard event.status != .cancelled else { return false }
        return isWithinClaimWindow && !reporterClaimIsMine
    }

    private var isWithinClaimWindow: Bool {
        let windowStart = event.eventDate.addingTimeInterval(-3600)
        let windowEnd = event.eventDate.addingTimeInterval(3600)
        let now = Date()
        return now >= windowStart && now <= windowEnd
    }

    private var claimDisabledForCurrentUser: Bool {
        guard let claim = liveActivityManager.activeClaims[event.id] else { return false }
        return claim.reporterId != userPreferences.userIdentifier
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

    private func handleClaimAction() {
        guard userPreferences.isSignedIn else {
            alertMessage = "Sign in to claim the reporter role."
            return
        }

        guard supportsLiveActivity else {
            alertMessage = "Live Activities currently support Soccer, Football, and Cross Country."
            return
        }

        guard isWithinClaimWindow else {
            alertMessage = "Reporter signups open one hour before the game and close one hour after it starts."
            return
        }

        isClaimLoading = true

        Task {
            do {
                _ = try await liveActivityManager.claimReporter(
                    for: event,
                    reporterId: userPreferences.userIdentifier,
                    reporterName: userPreferences.userName.isEmpty ? "Reporter" : userPreferences.userName
                )
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
                isClaimLoading = false
            }
        }
    }

    private func surrenderReportingSpot() {
        isClaimLoading = true

        Task {
            await liveActivityManager.releaseReporter(eventId: event.id)
            await MainActor.run {
                isClaimLoading = false
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

    private func triggerStartReporting() {
        if let onStartReporting {
            onStartReporting()
        } else {
            alertMessage = "Reporter console coming soon."
        }
    }
}

@available(iOS 16.2, *)
struct ReporterConsoleView: View {
    let event: SportsEvent

    @ObservedObject private var liveActivityManager = SportsLiveActivityManager.shared
    @ObservedObject private var userPreferences = UserPreferences.shared
    @Environment(\.dismiss) private var dismiss

    @State private var status: SportsActivityAttributes.GameStatus = .live
    @State private var homeScore: Int = 0
    @State private var awayScore: Int = 0
    @State private var periodLabel: String = ""
    @State private var clockMinutes: Int = 0
    @State private var clockSeconds: Int = 0
    @State private var possession: SportsActivityAttributes.TeamSide? = nil
    @State private var summary: String = ""
    @State private var highlightIcon: String? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var sportType: SportsActivityAttributes.SportType? {
        SportsActivityAttributes.SportType(eventSport: event.sport)
    }

    private var reporterName: String {
        let name = userPreferences.userName
        return name.isEmpty ? "Reporter" : name
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Game Status") {
                    Picker("Status", selection: $status) {
                        ForEach(SportsActivityAttributes.GameStatus.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    TextField("Period / Quarter", text: $periodLabel)
                }

                if sportType != .some(.crossCountry) {
                    Section("Scoreboard") {
                        Stepper("Middlesex: \(homeScore)", value: $homeScore, in: 0...200)
                        Stepper("\(event.opponent): \(awayScore)", value: $awayScore, in: 0...200)
                    }

                    Section("Possession") {
                        Picker("Possession", selection: Binding(
                            get: { possession ?? .middlesex },
                            set: { possession = $0 }
                        )) {
                            Text("Middlesex").tag(SportsActivityAttributes.TeamSide.middlesex)
                            Text(event.opponent).tag(SportsActivityAttributes.TeamSide.opponent)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Clock") {
                    if status == .live {
                        Stepper("Minutes: \(clockMinutes)", value: $clockMinutes, in: 0...120)
                        Stepper("Seconds: \(clockSeconds)", value: $clockSeconds, in: 0...59)
                    } else {
                        Text("Clock updates only apply while status is Live.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Highlight / Summary") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 100)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        publishUpdate()
                    } label: {
                        Label("Publish Update", systemImage: "paperplane.fill")
                    }
                    .disabled(isSaving)

                    Button(role: .destructive) {
                        releaseClaim()
                    } label: {
                        Label("Surrender Reporting Spot", systemImage: "person.crop.circle.badge.minus")
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Reporter Console")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await loadInitialState()
        }
    }

    @MainActor
    private func loadInitialState() async {
        if let activity = liveActivityManager.activeActivities[event.id] {
            apply(state: activity.content.state)
        } else if let latest = try? await SportsLiveCloudKitService.shared.fetchLatestUpdate(for: event.id) {
            apply(state: latest.state)
        } else {
            applyDefaults()
        }
    }

    @MainActor
    private func apply(state: SportsActivityAttributes.ContentState) {
        status = state.status
        homeScore = max(0, state.homeScore ?? event.middlesexScore)
        awayScore = max(0, state.awayScore ?? event.opponentScore)
        periodLabel = state.periodLabel ?? ""
        summary = state.lastEventSummary ?? ""
        possession = state.possession
        highlightIcon = state.highlightIcon ?? sportType?.iconName
        clockMinutes = 0
        clockSeconds = 0

        let remaining = state.currentClockRemaining() ?? state.clockRemaining ?? 0
        if remaining > 0 {
            let total = Int(remaining.rounded(.down))
            clockMinutes = total / 60
            clockSeconds = total % 60
        }
    }

    @MainActor
    private func applyDefaults() {
        status = defaultStatus(for: event.status)
        homeScore = max(0, event.middlesexScore)
        awayScore = max(0, event.opponentScore)
        possession = .middlesex
        highlightIcon = sportType?.iconName
        clockMinutes = 0
        clockSeconds = 0

        let remaining = max(event.eventDate.timeIntervalSince(Date()), 0)
        if remaining > 0 {
            let total = Int(remaining.rounded(.down))
            clockMinutes = total / 60
            clockSeconds = total % 60
        }
    }

    @MainActor
    private func publishUpdate() {
        guard let sportType else {
            errorMessage = "This sport does not yet support Live Activities."
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            let now = Date()
            let clockTotal = max(0, clockMinutes * 60 + clockSeconds)

            let state = SportsActivityAttributes.ContentState(
                status: status,
                homeScore: sportType == .some(.crossCountry) ? nil : homeScore,
                awayScore: sportType == .some(.crossCountry) ? nil : awayScore,
                periodLabel: periodLabel.isEmpty ? nil : periodLabel,
                clockRemaining: status == .live ? Double(clockTotal) : nil,
                clockLastUpdated: status == .live ? now : nil,
                possession: sportType == .some(.crossCountry) ? nil : possession,
                lastEventSummary: summary.isEmpty ? nil : summary,
                lastEventDetail: nil,
                highlightIcon: highlightIcon ?? sportType.iconName,
                topFinishers: [],
                teamResults: [],
                updatedAt: now,
                reporterName: reporterName
            )

            let reporterId = userPreferences.userIdentifier.isEmpty ? nil : userPreferences.userIdentifier

            let update = SportsLiveUpdate(
                eventId: event.id,
                sport: sportType,
                state: state,
                summary: summary.isEmpty ? nil : summary,
                reporterId: reporterId,
                reporterName: reporterName
            )

            do {
                try await liveActivityManager.publish(update: update)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    @MainActor
    private func releaseClaim() {
        isSaving = true
        Task {
            await liveActivityManager.releaseReporter(eventId: event.id)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }

    private func defaultStatus(for status: SportsEvent.EventStatus) -> SportsActivityAttributes.GameStatus {
        switch status {
        case .scheduled: return .upcoming
        case .inProgress: return .live
        case .completed: return .final
        case .cancelled: return .final
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
