//
//  MiddlesexLiveActivityLiveActivity.swift
//  MiddlesexLiveActivity
//
//  Live Activity for tracking current class progress
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MiddlesexLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            // Lock Screen UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - shows when long-pressing
                DynamicIslandExpandedRegion(.leading) {
                    let accent = Color(hex: context.attributes.classColor) ?? .middlesexRed

                    HStack(alignment: .center, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: 4)
                            .padding(.vertical, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.attributes.className)
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text(context.attributes.block)
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.25))
                                    .clipShape(Capsule())

                                Text(context.attributes.room)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.75))

                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))

                                Text(context.attributes.teacher)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .lineLimit(1)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 10)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.endDate, style: .timer)
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(.white)

                        Text("remaining")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.trailing, 16)
                    .padding(.vertical, 10)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    let accent = Color(hex: context.attributes.classColor) ?? .middlesexRed

                    VStack(spacing: 10) {
                        // Progress bar with system timer
                        ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: false) {
                            EmptyView()
                        }
                        .progressViewStyle(.linear)
                        .tint(accent)
                        .frame(height: 3)

                        // Schedule details
                        HStack {
                            Text(context.attributes.startTime)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.white.opacity(0.65))

                            Spacer()

                            Text(context.attributes.teacher)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.65))

                            Spacer()

                            Text(context.attributes.endTime)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

            } compactLeading: {
                // Compact leading - shows block letter
                let accent = Color(hex: context.attributes.classColor) ?? .middlesexRed

                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)

                    Text(context.attributes.block)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // Compact trailing - shows time remaining using system timer
                Text(context.state.endDate, style: .timer)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                // Minimal - when multiple Live Activities are active
                let accent = Color(hex: context.attributes.classColor) ?? .middlesexRed

                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
            }
            .keylineTint(Color(hex: context.attributes.classColor) ?? .middlesexRed)
        }
    }

    // Helper: Format time remaining for expanded view
    private func timeRemainingText(_ timeRemaining: TimeInterval) -> String {
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", seconds))"
        } else {
            return "\(seconds)s"
        }
    }

    // Helper: Format time for compact view
    private func compactTimeText(_ timeRemaining: TimeInterval) -> String {
        let minutes = Int(timeRemaining / 60)

        if minutes > 0 {
            return "\(minutes)m"
        } else {
            let seconds = Int(timeRemaining)
            return "\(seconds)s"
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ClassActivityAttributes>

    var body: some View {
        let accent = Color(hex: context.attributes.classColor) ?? .middlesexRed

        VStack(spacing: 18) {
            // Header - class information
            HStack(alignment: .top, spacing: 16) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 6, height: 44)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.className)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(context.attributes.block)
                                .font(.caption.bold())
                                .foregroundColor(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white)
                                .clipShape(Capsule())

                            Text(context.attributes.teacher)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))

                            Text(context.attributes.room)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .lineLimit(1)
                    }
                }

                Spacer()

                // Timer
                VStack(alignment: .trailing, spacing: 4) {
                    Text(context.state.endDate, style: .timer)
                        .font(.title.bold().monospacedDigit())
                        .foregroundColor(.white)

                    Text("remaining")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Progress bar
            ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: false) {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(.white)
            .frame(height: 3)

            // Footer times
            HStack {
                Text(context.attributes.startTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.75))

                Spacer()

                Text(context.attributes.block)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                Text(context.attributes.endTime)
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(accent)
        .activityBackgroundTint(accent)
        .activitySystemActionForegroundColor(.white)
    }
}

private extension Color {
    static let middlesexRed = Color(red: 200/255, green: 16/255, blue: 46/255)
}

@available(iOS 16.2, *)
struct MiddlesexSportsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SportsActivityAttributes.self) { context in
            SportsLockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.homeTeamName)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Text(context.attributes.opponentTeamName)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        let state = context.state
                        let clockText = state.formattedClock(at: timeline.date) ?? state.periodLabel

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(sportsScoreText(state.homeScore)) - \(sportsScoreText(state.awayScore))")
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.white)

                            if let clockText = clockText {
                                Text(clockText)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Text(state.status.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.sportType == .crossCountry {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(context.state.topFinishers.prefix(2), id: \.position) { finisher in
                                Text("#\(finisher.position) \(finisher.name) – \(finisher.finishTime)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    } else if let summary = context.state.lastEventSummary {
                        Text(summary)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    } else {
                        Text(context.state.status == .live ? "Awaiting play update…" : "No updates yet.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.sportType.iconName)
                    .foregroundColor(.white)
            } compactTrailing: {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let state = context.state
                    let clockText = state.formattedClock(at: timeline.date) ?? state.periodLabel

                    Text(clockText ?? state.status.displayName.prefix(3).uppercased())
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white)
                }
            } minimal: {
                Circle()
                    .fill(context.attributes.sportType.themeColor)
                    .frame(width: 12, height: 12)
            }
            .keylineTint(context.attributes.sportType.themeColor)
        }
    }
}

@available(iOS 16.2, *)
struct SportsLockScreenLiveActivityView: View {
    let context: ActivityViewContext<SportsActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let state = context.state
            let clockText = state.formattedClock(at: timeline.date)
            let highlight = highlightText(for: state)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(context.attributes.sportType.displayName, systemImage: context.attributes.sportType.iconName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Text(state.status.displayName.uppercased())
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }

                if context.attributes.sportType == .crossCountry {
                    crossCountrySummary(state: state)
                } else {
                    scoreboardView(state: state)

                    if let periodLabel = state.periodLabel ?? clockText {
                        Text(periodLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if let possession = state.possession, context.attributes.sportType == .football {
                        Text("Possession: \(possession.description(homeTeam: context.attributes.homeTeamName, opponentTeam: context.attributes.opponentTeamName))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if let highlight = highlight {
                        Text(highlight)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                if let reporter = state.reporterName {
                    Text("Reporter: \(reporter)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(context.attributes.sportType.themeColor.opacity(0.92))
        .activityBackgroundTint(context.attributes.sportType.themeColor.opacity(0.92))
        .activitySystemActionForegroundColor(.white)
    }

    private func scoreboardView(state: SportsActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(context.attributes.homeTeamName)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Text(sportsScoreText(state.homeScore))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(.white)
            }

            HStack {
                Text(context.attributes.opponentTeamName)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(sportsScoreText(state.awayScore))
                    .font(.headline.monospacedDigit())
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private func crossCountrySummary(state: SportsActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !state.topFinishers.isEmpty {
                Text("Top Finishers")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.9))

                ForEach(state.topFinishers.prefix(3), id: \.position) { finisher in
                    HStack {
                        Text("#\(finisher.position)")
                            .font(.caption.bold())
                            .frame(width: 30, alignment: .leading)
                            .foregroundColor(.white.opacity(0.7))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(finisher.name)
                                .font(.caption)
                                .foregroundColor(.white)

                            Text("\(finisher.school) • \(finisher.finishTime)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }

            if !state.teamResults.isEmpty {
                Text("Team Standings")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.9))

                ForEach(state.teamResults.prefix(3), id: \.position) { result in
                    HStack {
                        Text("#\(result.position)")
                            .font(.caption.bold())
                            .frame(width: 30, alignment: .leading)
                            .foregroundColor(.white.opacity(0.7))

                        Text("\(result.school) • \(result.points) pts")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func highlightText(for state: SportsActivityAttributes.ContentState) -> String? {
        if let summary = state.lastEventSummary {
            return summary
        }

        switch state.status {
        case .upcoming:
            return "Game will begin soon."
        case .live:
            return "Live updates will appear here."
        case .final:
            return "Final score posted."
        }
    }
}

@available(iOS 16.2, *)
private func sportsScoreText(_ score: Int?) -> String {
    if let score = score, score >= 0 {
        return "\(score)"
    } else {
        return "–"
    }
}

// Color extension to support hex colors
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

private extension ClassActivityAttributes.ContentState {
    func metrics(at date: Date) -> (timeRemaining: TimeInterval, progress: Double) {
        let clampedDate = min(max(date, startDate), endDate)
        let totalDuration = max(endDate.timeIntervalSince(startDate), 1)
        let elapsed = clampedDate.timeIntervalSince(startDate)
        let progress = min(max(elapsed / totalDuration, 0), 1)
        let timeRemaining = max(endDate.timeIntervalSince(clampedDate), 0)
        return (timeRemaining, progress)
    }
}

@available(iOS 16.2, *)
private extension SportsActivityAttributes.TeamSide {
    func description(homeTeam: String, opponentTeam: String) -> String {
        switch self {
        case .middlesex:
            return homeTeam
        case .opponent:
            return opponentTeam
        }
    }
}

#Preview("Notification", as: .content, using: ClassActivityAttributes(
    className: "AP Calculus BC",
    teacher: "Mr. Smith",
    room: "Math 101",
    block: "A",
    startTime: "8:25",
    endTime: "9:05",
    classColor: "#1E90FF"
)) {
   MiddlesexLiveActivityLiveActivity()
} contentStates: {
    ClassActivityAttributes.ContentState(timeRemaining: 1200, progress: 0.5, currentTime: Date(), startDate: Date().addingTimeInterval(-600), endDate: Date().addingTimeInterval(600))
    ClassActivityAttributes.ContentState(timeRemaining: 300, progress: 0.85, currentTime: Date(), startDate: Date().addingTimeInterval(-1800), endDate: Date().addingTimeInterval(300))
}
