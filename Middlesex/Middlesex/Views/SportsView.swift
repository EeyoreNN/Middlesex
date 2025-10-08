//
//  SportsView.swift
//  Middlesex
//
//  Sports schedules, scores, and team information
//

import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

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
    @State private var autoPublishTask: Task<Void, Never>? = nil
    @State private var didLoadInitialState = false
    @State private var isGameClockRunning = false
    @State private var gameClockTimer: Timer? = nil
    @State private var gameClockStartDate: Date? = nil
    @State private var gameClockRemainingSeconds: Int = 0
    @State private var raceAccumulatedElapsed: TimeInterval = 0
    @State private var selectedScoringTeam: SportsActivityAttributes.TeamSide = .middlesex
    @State private var scorerInput: String = ""
    @State private var knownScorers: Set<String> = []
    private struct LoggedEvent: Identifiable, Equatable {
        let id: UUID
        var text: String
        var timestamp: Date

        init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
            self.id = id
            self.text = text
            self.timestamp = timestamp
        }
    }

    @State private var eventLog: [LoggedEvent] = []
    @State private var finishers: [FinisherEntry] = []
    @State private var raceStartDate: Date? = nil
    @State private var raceTimer: Timer? = nil

    private struct FinisherEntry: Identifiable, Equatable {
        let id: UUID
        var place: Int
        var elapsed: TimeInterval
        var name: String
        var school: String

        init(id: UUID = UUID(), place: Int, elapsed: TimeInterval, name: String = "", school: String = "") {
            self.id = id
            self.place = place
            self.elapsed = elapsed
            self.name = name
            self.school = school
        }
    }

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
                    if sportType == .some(.crossCountry) {
                        crossCountryClockControls
                    } else {
                        if status == .live {
                            Stepper("Minutes: \(clockMinutes)", value: $clockMinutes, in: 0...120)
                                .disabled(isGameClockRunning)
                            Stepper("Seconds: \(clockSeconds)", value: $clockSeconds, in: 0...59)
                                .disabled(isGameClockRunning)
                        } else {
                            Text("Clock updates only apply while status is Live.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            if isGameClockRunning {
                                Button("Pause Clock") {
                                    pauseGameClock()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                Button("Start Clock") {
                                    startGameClock()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(clockMinutes == 0 && clockSeconds == 0)
                            }

                            Button("Reset Clock", role: .destructive) {
                                resetGameClock()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                    }
                }

                if let sportType {
                    sportSpecificSections(for: sportType)
                }

                Section("Highlight / Summary") {
                    TextEditor(text: $summary)
                        .frame(minHeight: 100)
                }

                if !eventLog.isEmpty {
                    Section("Recent Events") {
                        ForEach($eventLog) { $entry in
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Event description", text: $entry.text)
                                    .textInputAutocapitalization(.sentences)
                                    .onSubmit { scheduleAutoPublish() }
                                    .onChange(of: entry.text) { _ in scheduleAutoPublish() }

                                HStack {
                                    Text(entry.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Button(role: .destructive) {
                                        removeEvent(entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        Button("Clear Event Log", role: .destructive) {
                            eventLog.removeAll()
                            summary = ""
                            scheduleAutoPublish()
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
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
        .onDisappear {
            autoPublishTask?.cancel()
            gameClockTimer?.invalidate()
            gameClockTimer = nil
            raceTimer?.invalidate()
        }
        .onChange(of: status) { scheduleAutoPublish() }
        .onChange(of: homeScore) { scheduleAutoPublish() }
        .onChange(of: awayScore) { scheduleAutoPublish() }
        .onChange(of: periodLabel) { scheduleAutoPublish() }
        .onChange(of: possession) { scheduleAutoPublish() }
        .onChange(of: clockMinutes) {
            if sportType != .some(.crossCountry) {
                if !isGameClockRunning {
                    gameClockRemainingSeconds = max(0, clockMinutes * 60 + clockSeconds)
                }
                scheduleAutoPublish()
            }
        }
        .onChange(of: clockSeconds) {
            if sportType != .some(.crossCountry) {
                if !isGameClockRunning {
                    gameClockRemainingSeconds = max(0, clockMinutes * 60 + clockSeconds)
                }
                scheduleAutoPublish()
            }
        }
        .onChange(of: summary) { scheduleAutoPublish() }
        .onChange(of: finishers) {
            if sportType == .some(.crossCountry) {
                summary = finishersSummaryText
                scheduleAutoPublish()
            }
        }
    }

    @ViewBuilder
    private func sportSpecificSections(for sport: SportsActivityAttributes.SportType) -> some View {
        switch sport {
        case .football:
            footballQuickActionsSection
        case .soccer:
            soccerQuickActionsSection
        case .crossCountry:
            crossCountrySections
        }
    }

    @ViewBuilder
    private var footballQuickActionsSection: some View {
        Section("Football Scoring") {
            Picker("Team", selection: $selectedScoringTeam) {
                Text("Middlesex").tag(SportsActivityAttributes.TeamSide.middlesex)
                Text(event.opponent).tag(SportsActivityAttributes.TeamSide.opponent)
            }
            .pickerStyle(.segmented)

            scorerInputField

            HStack(spacing: 12) {
                Button("Touchdown") { handleFootballEvent(.touchdown) }
                Button("Field Goal") { handleFootballEvent(.fieldGoal) }
                Button("Safety") { handleFootballEvent(.safety) }
                Button("Extra Point") { handleFootballEvent(.extraPoint) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var soccerQuickActionsSection: some View {
        Section("Soccer Goal") {
            scorerInputField

            HStack(spacing: 12) {
                Button("Goal - Middlesex") { recordSoccerGoal(for: .middlesex) }
                Button("Goal - \(event.opponent)") { recordSoccerGoal(for: .opponent) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var crossCountrySections: some View {
        Section("Finishers") {
            if finishers.isEmpty {
                Text("Tap \"Log Finisher\" as athletes cross the line. You can fill in names later.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach($finishers) { $finisher in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("#\(finisher.place)")
                            .font(.headline)
                        Spacer()
                        Text(formattedElapsed(finisher.elapsed))
                            .font(.subheadline.monospacedDigit())
                    }

                    TextField("Athlete name", text: $finisher.name)
                        .textInputAutocapitalization(.words)

                    TextField("School", text: $finisher.school)
                        .textInputAutocapitalization(.words)

                    HStack {
                        Button("Update Time to Now") {
                            if let start = raceStartDate {
                                finisher.elapsed = Date().timeIntervalSince(start)
                                scheduleAutoPublish()
                            }
                        }
                        .disabled(raceStartDate == nil)

                        Spacer()

                        Button(role: .destructive) {
                            removeFinisher(withId: finisher.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }

            Button("Log Finisher") {
                logCrossCountryFinisher()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var crossCountryClockControls: some View {
        let elapsedDisplay = formattedElapsedFromClock()

        Text("Elapsed: \(elapsedDisplay)")
            .font(.title3.monospacedDigit())

        HStack(spacing: 12) {
            if raceStartDate == nil {
                if raceAccumulatedElapsed > 0 {
                    Button("Resume Clock") {
                        startCrossCountryClock()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("Reset Clock", role: .destructive) {
                        resetCrossCountryClock()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Start Clock") {
                        startCrossCountryClock()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Button("Pause Clock") {
                    pauseCrossCountryClock()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Reset Clock", role: .destructive) {
                    resetCrossCountryClock()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
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
        didLoadInitialState = true
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

        eventLog = summary
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { LoggedEvent(text: $0) }

        if !state.topFinishers.isEmpty {
            finishers = state.topFinishers.enumerated().map { index, finisher in
                FinisherEntry(
                    place: index + 1,
                    elapsed: timeInterval(from: finisher.finishTime),
                    name: finisher.name == "Pending" ? "" : finisher.name,
                    school: finisher.school
                )
            }
        } else {
            finishers = []
        }

        if sportType == .some(.crossCountry) {
            summary = finishersSummaryText
        } else {
            summary = eventLog.map { $0.text }.joined(separator: "\n")
        }

        gameClockTimer?.invalidate()
        gameClockTimer = nil
        isGameClockRunning = false
        gameClockStartDate = nil

        if sportType == .some(.crossCountry) {
            raceTimer?.invalidate()
            raceTimer = nil
            raceStartDate = nil
            raceAccumulatedElapsed = Double(clockMinutes * 60 + clockSeconds)
        } else {
            raceTimer?.invalidate()
            raceTimer = nil
            raceStartDate = nil
            raceAccumulatedElapsed = 0
        }

        let remaining = state.currentClockRemaining() ?? state.clockRemaining ?? 0
        if remaining > 0 {
            let total = Int(remaining.rounded(.down))
            clockMinutes = total / 60
            clockSeconds = total % 60
        }

        gameClockRemainingSeconds = clockMinutes * 60 + clockSeconds
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
        finishers = []
        eventLog = []
        summary = ""
        knownScorers.removeAll()
        isGameClockRunning = false
        gameClockTimer?.invalidate()
        gameClockTimer = nil
        gameClockStartDate = nil
        gameClockRemainingSeconds = 0
        raceAccumulatedElapsed = 0

        let remaining = max(event.eventDate.timeIntervalSince(Date()), 0)
        if remaining > 0 {
            let total = Int(remaining.rounded(.down))
            clockMinutes = total / 60
            clockSeconds = total % 60
        }

        gameClockRemainingSeconds = clockMinutes * 60 + clockSeconds
    }

    @MainActor
    private func publishUpdate(auto: Bool = false) {
        guard let sportType else {
            if !auto {
                errorMessage = "This sport does not yet support Live Activities."
            }
            return
        }

        if !auto {
            isSaving = true
            errorMessage = nil
        }

        Task {
            let now = Date()
            let clockTotal = max(0, clockMinutes * 60 + clockSeconds)

            let finishersState = finishers
                .sorted { $0.place < $1.place }
                .map { entry in
                    SportsActivityAttributes.Finisher(
                        position: entry.place,
                        name: entry.name.isEmpty ? "Pending" : entry.name,
                        school: entry.school,
                        finishTime: stringFromElapsed(entry.elapsed)
                    )
                }

            let summaryText: String = {
                if !summary.isEmpty {
                    return summary
                }
                if !eventLog.isEmpty {
                    return eventLog.map { $0.text }.joined(separator: "\n")
                }
                if sportType == .crossCountry {
                    return finishersSummaryText
                }
                return ""
            }()

            let icon = highlightIcon ?? sportType.iconName

            let state = SportsActivityAttributes.ContentState(
                status: status,
                homeScore: sportType == .crossCountry ? nil : homeScore,
                awayScore: sportType == .crossCountry ? nil : awayScore,
                periodLabel: periodLabel.isEmpty ? nil : periodLabel,
                clockRemaining: status == .live ? Double(clockTotal) : nil,
                clockLastUpdated: status == .live ? now : nil,
                possession: sportType == .crossCountry ? nil : possession,
                lastEventSummary: summaryText.isEmpty ? nil : summaryText,
                lastEventDetail: nil,
                highlightIcon: icon,
                topFinishers: finishersState,
                teamResults: [],
                updatedAt: now,
                reporterName: reporterName
            )

            let reporterId = userPreferences.userIdentifier.isEmpty ? nil : userPreferences.userIdentifier

            let update = SportsLiveUpdate(
                eventId: event.id,
                sport: sportType,
                state: state,
                summary: summaryText.isEmpty ? nil : summaryText,
                reporterId: reporterId,
                reporterName: reporterName
            )

            do {
                try await liveActivityManager.publish(update: update)
                await MainActor.run {
                    if auto {
                        isSaving = false
                    } else {
                        isSaving = false
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    if !auto {
                        isSaving = false
                    }
                }
            }
        }
    }

    @MainActor
    private func releaseClaim() {
        isSaving = true
        gameClockTimer?.invalidate()
        gameClockTimer = nil
        isGameClockRunning = false
        raceTimer?.invalidate()
        raceTimer = nil
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

    @ViewBuilder
    private var scorerInputField: some View {
        TextField("Scorer name", text: $scorerInput)
            .textInputAutocapitalization(.words)

        if !filteredKnownScorers.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filteredKnownScorers, id: \.self) { name in
                        Button(name) {
                            chooseKnownScorer(name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var filteredKnownScorers: [String] {
        let query = scorerInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Array(knownScorers)
            .filter { query.isEmpty || $0.lowercased().contains(query) }
            .sorted()
    }

    private enum FootballQuickEvent {
        case touchdown
        case fieldGoal
        case safety
        case extraPoint

        var points: Int {
            switch self {
            case .touchdown: return 6
            case .fieldGoal: return 3
            case .safety: return 2
            case .extraPoint: return 1
            }
        }

        var label: String {
            switch self {
            case .touchdown: return "Touchdown"
            case .fieldGoal: return "Field Goal"
            case .safety: return "Safety"
            case .extraPoint: return "Extra Point"
            }
        }
    }

    private func handleFootballEvent(_ event: FootballQuickEvent) {
        guard sportType == .some(.football) else { return }

        adjustScore(for: selectedScoringTeam, points: event.points)
        status = .live

        let scorerName = scorerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scorerName.isEmpty {
            knownScorers.insert(scorerName)
        }

        let teamName = teamDisplayName(selectedScoringTeam)
        let description = scorerName.isEmpty
            ? "\(timestampString()) - \(teamName) \(event.label)"
            : "\(timestampString()) - \(teamName) \(event.label) by \(scorerName)"

        appendEvent(description)
        scorerInput = ""
        scheduleAutoPublish()
    }

    private func recordSoccerGoal(for team: SportsActivityAttributes.TeamSide) {
        guard sportType == .some(.soccer) else { return }

        adjustScore(for: team, points: 1)
        status = .live

        let scorerName = scorerInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scorerName.isEmpty {
            knownScorers.insert(scorerName)
        }

        let teamName = teamDisplayName(team)
        let description = scorerName.isEmpty
            ? "\(timestampString()) - \(teamName) Goal"
            : "\(timestampString()) - \(teamName) Goal by \(scorerName)"

        appendEvent(description)
        scorerInput = ""
        scheduleAutoPublish()
    }

    private func adjustScore(for team: SportsActivityAttributes.TeamSide, points: Int) {
        if team == .middlesex {
            homeScore = max(0, homeScore + points)
        } else {
            awayScore = max(0, awayScore + points)
        }
    }

    private func appendEvent(_ text: String) {
        if text.isEmpty { return }
        eventLog.insert(LoggedEvent(text: text), at: 0)
        if eventLog.count > 25 {
            eventLog = Array(eventLog.prefix(25))
        }
        if sportType != .some(.crossCountry) {
            summary = eventLog.map { $0.text }.joined(separator: "\n")
        }
        scheduleAutoPublish()
    }

    private func removeEvent(_ id: UUID) {
        eventLog.removeAll { $0.id == id }
        if sportType != .some(.crossCountry) {
            summary = eventLog.map { $0.text }.joined(separator: "\n")
        }
        scheduleAutoPublish()
    }

    private func chooseKnownScorer(_ name: String) {
        scorerInput = name
    }

    private func timestampString() -> String {
        String(format: "%02d:%02d", max(0, clockMinutes), max(0, clockSeconds))
    }

    private func teamDisplayName(_ team: SportsActivityAttributes.TeamSide) -> String {
        switch team {
        case .middlesex:
            return "Middlesex"
        case .opponent:
            return event.opponent
        }
    }

    private func startCrossCountryClock() {
        if raceStartDate == nil {
            raceStartDate = Date()
            status = .live
            updateCrossCountryClock()
            raceTimer?.invalidate()
            raceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async {
                    updateCrossCountryClock()
                }
            }
            scheduleAutoPublish()
        }
    }

    private func resetCrossCountryClock() {
        raceTimer?.invalidate()
        raceTimer = nil
        raceStartDate = nil
        raceAccumulatedElapsed = 0
        clockMinutes = 0
        clockSeconds = 0
        scheduleAutoPublish()
    }

    private func updateCrossCountryClock() {
        let elapsed = totalRaceElapsed()
        clockMinutes = max(0, Int(elapsed) / 60)
        clockSeconds = max(0, Int(elapsed) % 60)
        // NOTE: Do NOT publish on every tick - TimelineView handles UI updates
        // Clock updates are calculated in real-time by the Live Activity widget
    }

    private func pauseCrossCountryClock() {
        guard let start = raceStartDate else { return }
        raceAccumulatedElapsed += Date().timeIntervalSince(start)
        raceStartDate = nil
        raceTimer?.invalidate()
        raceTimer = nil
        updateCrossCountryClock()
        scheduleAutoPublish()
    }

    private func logCrossCountryFinisher() {
        if raceStartDate == nil && raceAccumulatedElapsed == 0 {
            startCrossCountryClock()
        }

        let elapsed: TimeInterval = totalRaceElapsed()

        let place = finishers.count + 1
        finishers.append(FinisherEntry(place: place, elapsed: elapsed))
        appendEvent("Finisher #\(place) recorded at \(formattedElapsed(elapsed))")
        summary = finishersSummaryText
        scheduleAutoPublish()
    }

    private func removeFinisher(withId id: UUID) {
        finishers.removeAll { $0.id == id }
        recalculateFinisherPlaces()
        summary = finishersSummaryText
        scheduleAutoPublish()
    }

    private func recalculateFinisherPlaces() {
        finishers = finishers
            .sorted { $0.place < $1.place }
            .enumerated()
            .map { index, entry in
                var updated = entry
                updated.place = index + 1
                return updated
            }
    }

    private func formattedElapsedFromClock() -> String {
        if sportType == .some(.crossCountry) {
            return formattedElapsed(totalRaceElapsed())
        } else {
            return formattedElapsed(TimeInterval(clockMinutes * 60 + clockSeconds))
        }
    }

    private func formattedElapsed(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func stringFromElapsed(_ interval: TimeInterval) -> String {
        formattedElapsed(interval)
    }

    private func totalRaceElapsed() -> TimeInterval {
        if let start = raceStartDate {
            return raceAccumulatedElapsed + Date().timeIntervalSince(start)
        } else {
            return raceAccumulatedElapsed
        }
    }

    private var finishersSummaryText: String {
        guard !finishers.isEmpty else { return "" }
        return finishers
            .sorted { $0.place < $1.place }
            .map { entry in
                let name = entry.name.isEmpty ? "Pending" : entry.name
                let school = entry.school.isEmpty ? "" : " (\(entry.school))"
                return "#\(entry.place) \(name)\(school) – \(formattedElapsed(entry.elapsed))"
            }
            .joined(separator: "\n")
    }

    private func timeInterval(from finishTime: String) -> TimeInterval {
        let components = finishTime.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return 0
        }
        return TimeInterval(minutes * 60 + seconds)
    }

    private func scheduleAutoPublish(immediate: Bool = false) {
        guard didLoadInitialState else { return }

        if immediate {
            autoPublishTask?.cancel()
            autoPublishTask = nil
            publishUpdate(auto: true)
            return
        }

        autoPublishTask?.cancel()
        autoPublishTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                publishUpdate(auto: true)
            }
        }
    }

    private func startGameClock() {
        gameClockTimer?.invalidate()
        gameClockRemainingSeconds = max(0, clockMinutes * 60 + clockSeconds)
        guard gameClockRemainingSeconds > 0 else { return }
        gameClockStartDate = Date()
        isGameClockRunning = true
        status = .live
        gameClockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                updateGameClockTick()
            }
        }
        // Publish once when clock starts, then TimelineView handles the ticking
        scheduleAutoPublish()
    }

    private func pauseGameClock() {
        updateGameClockTick()
        gameClockTimer?.invalidate()
        gameClockTimer = nil
        isGameClockRunning = false
        gameClockStartDate = nil
        gameClockRemainingSeconds = max(0, clockMinutes * 60 + clockSeconds)
        scheduleAutoPublish()
    }

    private func resetGameClock() {
        pauseGameClock()
        clockMinutes = 0
        clockSeconds = 0
        gameClockRemainingSeconds = 0
        scheduleAutoPublish()
    }

    private func updateGameClockTick() {
        guard isGameClockRunning, let startDate = gameClockStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(startDate))
        let remaining = max(0, gameClockRemainingSeconds - elapsed)
        clockMinutes = remaining / 60
        clockSeconds = remaining % 60
        if remaining == 0 {
            pauseGameClock()
        }
        // NOTE: Do NOT publish on every tick - TimelineView handles UI updates
        // Only publish when clock reaches 0 (handled by pauseGameClock above)
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
