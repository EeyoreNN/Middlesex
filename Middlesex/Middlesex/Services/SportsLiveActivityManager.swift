//
//  SportsLiveActivityManager.swift
//  Middlesex
//
//  Coordinates sports Live Activities, CloudKit updates, and reporter workflow.
//

import Foundation
import ActivityKit
import Combine
import UIKit

@available(iOS 16.2, *)
@MainActor
class SportsLiveActivityManager: ObservableObject {
    static let shared = SportsLiveActivityManager()

    @Published private(set) var activeActivities: [String: Activity<SportsActivityAttributes>] = [:]
    @Published private(set) var activeClaims: [String: SportsReporterClaim] = [:]

    private var pushTokenTasks: [String: Task<Void, Never>] = [:]
    private let cloudService = SportsLiveCloudKitService.shared

    private init() {
        Task {
            await restoreExistingActivities()
        }
    }

    // MARK: - Following

    func isFollowing(eventId: String) -> Bool {
        activeActivities[eventId] != nil
    }

    func follow(event: SportsEvent, userPreferences: UserPreferences) async throws {
        guard let sportType = SportsActivityAttributes.SportType(eventSport: event.sport) else {
            print("⚠️ Unsupported sport for Live Activity: \(event.sport.rawValue)")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "SportsLiveActivityManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled in Settings."])
        }

        if let existing = activeActivities[event.id] {
            print("ℹ️ Already following event \(existing.id)")
            return
        }

        var initialState = SportsActivityAttributes.ContentState(status: .upcoming, updatedAt: Date())

        if let latest = try? await cloudService.fetchLatestUpdate(for: event.id) {
            initialState = latest.state
        } else {
            initialState.homeScore = event.middlesexScore >= 0 ? event.middlesexScore : nil
            initialState.awayScore = event.opponentScore >= 0 ? event.opponentScore : nil
            initialState.periodLabel = "Starts \(event.eventDate.formatted(date: .omitted, time: .shortened))"
        }

        if initialState.reporterName == nil {
            initialState.reporterName = activeClaims[event.id]?.reporterName
        }

        let attributes = SportsActivityAttributes(
            sportType: sportType,
            eventId: event.id,
            eventName: "\(event.isHome ? "vs" : "@") \(event.opponent)",
            opponent: event.opponent,
            location: event.location,
            startDate: event.eventDate,
            homeTeamName: "Middlesex",
            opponentTeamName: event.opponent,
            reporterName: initialState.reporterName
        )

        let staleDate = event.eventDate.addingTimeInterval(4 * 60 * 60)

        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: staleDate),
            pushType: .token
        )

        activeActivities[event.id] = activity
        listenForPushTokens(activity, eventId: event.id, sport: sportType, userPreferences: userPreferences)
    }

    func stopFollowing(eventId: String, userPreferences: UserPreferences, dismissAfter: TimeInterval = 60) async {
        guard let activity = activeActivities[eventId] else { return }
        activeActivities.removeValue(forKey: eventId)

        pushTokenTasks[eventId]?.cancel()
        pushTokenTasks[eventId] = nil

        await activity.end(.init(state: activity.content.state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(dismissAfter)))

        if !userPreferences.userIdentifier.isEmpty {
            try? await cloudService.removeSubscription(eventId: eventId, userId: userPreferences.userIdentifier)
        }
    }

    // MARK: - Updates

    func publish(update: SportsLiveUpdate) async throws {
        try await cloudService.saveUpdate(update)

        if let activity = activeActivities[update.eventId] {
            await activity.update(.init(state: update.state, staleDate: activity.content.staleDate))
        }
    }

    func refreshFromCloud(eventId: String) async {
        guard let activity = activeActivities[eventId] else { return }

        do {
            if let latest = try await cloudService.fetchLatestUpdate(for: eventId) {
                await activity.update(.init(state: latest.state, staleDate: activity.content.staleDate))
            }
        } catch {
            print("❌ Failed to refresh live activity: \(error)")
        }
    }

    // MARK: - Reporter Claims

    func fetchActiveClaim(eventId: String) async {
        do {
            if let claim = try await cloudService.fetchActiveClaim(for: eventId) {
                activeClaims[eventId] = claim
            } else {
                activeClaims.removeValue(forKey: eventId)
            }
        } catch {
            print("❌ Failed to fetch reporter claim: \(error)")
        }
    }

    func claimReporter(
        for event: SportsEvent,
        reporterId: String,
        reporterName: String,
        window: TimeInterval = 3 * 60 * 60
    ) async throws -> SportsReporterClaim {
        let claim = try await cloudService.claimReporter(eventId: event.id, reporterId: reporterId, reporterName: reporterName, duration: window)
        activeClaims[event.id] = claim

        if let activity = activeActivities[event.id] {
            var state = activity.content.state
            state.reporterName = reporterName
            await activity.update(.init(state: state, staleDate: activity.content.staleDate))
        }

        return claim
    }

    func releaseReporter(eventId: String) async {
        do {
            try await cloudService.releaseReporter(eventId: eventId)
            activeClaims.removeValue(forKey: eventId)

            if let activity = activeActivities[eventId] {
                var state = activity.content.state
                state.reporterName = nil
                await activity.update(.init(state: state, staleDate: activity.content.staleDate))
            }
        } catch {
            print("❌ Failed to release reporter claim: \(error)")
        }
    }

    // MARK: - Restore

    private func restoreExistingActivities() async {
        for activity in Activity<SportsActivityAttributes>.activities {
            activeActivities[activity.attributes.eventId] = activity
            listenForPushTokens(activity, eventId: activity.attributes.eventId, sport: activity.attributes.sportType, userPreferences: UserPreferences.shared)
        }
    }

    // MARK: - Helpers

    private func listenForPushTokens(
        _ activity: Activity<SportsActivityAttributes>,
        eventId: String,
        sport: SportsActivityAttributes.SportType,
        userPreferences: UserPreferences
    ) {
        pushTokenTasks[eventId]?.cancel()
        pushTokenTasks[eventId] = Task {
            let userId = userPreferences.userIdentifier

            guard !userId.isEmpty else {
                for await _ in activity.pushTokenUpdates {
                    // Consume tokens but skip registration until user signs in
                }
                return
            }

            for await tokenData in activity.pushTokenUpdates {
                let subscription = SportsLiveSubscription(
                    id: "\(eventId)-\(userId)",
                    eventId: eventId,
                    userId: userId,
                    sport: sport,
                    pushToken: tokenData,
                    deviceName: UIDevice.current.name
                )

                do {
                    try await cloudService.registerSubscription(subscription)
                } catch {
                    print("❌ Failed to register live activity subscription: \(error)")
                }
            }
        }
    }
}

@available(iOS 16.2, *)
extension SportsActivityAttributes.SportType {
    init?(eventSport: SportsEvent.Sport) {
        switch eventSport {
        case .soccer:
            self = .soccer
        case .football:
            self = .football
        case .crossCountry:
            self = .crossCountry
        default:
            return nil
        }
    }
}
