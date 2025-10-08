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
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: context.attributes.classColor) ?? .red)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.block)
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.7))

                            Text(context.attributes.className)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timeRemainingText(context.state.timeRemaining))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundColor(.white)

                        Text("remaining")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Teacher and room
                        HStack(spacing: 16) {
                            Label(context.attributes.teacher, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))

                            Label(context.attributes.room, systemImage: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Capsule()
                                    .fill(Color.white.opacity(0.2))

                                // Progress
                                Capsule()
                                    .fill(Color(hex: context.attributes.classColor) ?? .red)
                                    .frame(width: geometry.size.width * context.state.progress)
                            }
                        }
                        .frame(height: 6)

                        // Times
                        HStack {
                            Text(context.attributes.startTime)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))

                            Spacer()

                            Text(context.attributes.endTime)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 12)
                }

            } compactLeading: {
                // Compact leading - shows block letter
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: context.attributes.classColor) ?? .red)
                        .frame(width: 6, height: 6)

                    Text(context.attributes.block)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            } compactTrailing: {
                // Compact trailing - shows time remaining
                Text(compactTimeText(context.state.timeRemaining))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.white)
            } minimal: {
                // Minimal - when multiple Live Activities are active
                Circle()
                    .fill(Color(hex: context.attributes.classColor) ?? .red)
                    .frame(width: 12, height: 12)
            }
            .keylineTint(Color(hex: context.attributes.classColor) ?? .red)
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
        TimelineView(.periodic(from: .now, interval: 1)) { timeline in
            let metrics = context.state.metrics(at: timeline.date)
            let timeText = LockScreenLiveActivityView.formattedTimeRemaining(metrics.timeRemaining)
            let progress = metrics.progress

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Color indicator
                    Circle()
                        .fill(Color(hex: context.attributes.classColor) ?? .red)
                        .frame(width: 10, height: 10)

                    // Class name
                    Text(context.attributes.className)
                        .font(.headline.bold())
                        .foregroundColor(.white)

                    Spacer()

                    // Time remaining
                    Text(timeText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Teacher and room
                HStack(spacing: 16) {
                    Label(context.attributes.teacher, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Label(context.attributes.room, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    // Block and times
                    Text("\(context.attributes.block) • \(context.attributes.startTime)-\(context.attributes.endTime)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.white.opacity(0.2))

                        // Progress
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .background(Color(hex: context.attributes.classColor)?.opacity(0.95) ?? Color.red.opacity(0.95))
        .activityBackgroundTint(Color(hex: context.attributes.classColor)?.opacity(0.95) ?? Color.red.opacity(0.95))
        .activitySystemActionForegroundColor(.white)
    }

    private static func formattedTimeRemaining(_ timeRemaining: TimeInterval) -> String {
        let minutes = Int(timeRemaining / 60)
        let seconds = Int(timeRemaining.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
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
