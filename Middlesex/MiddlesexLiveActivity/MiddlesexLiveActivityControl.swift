//
//  MiddlesexLiveActivityControl.swift
//  MiddlesexLiveActivity
//
//  Control Widget for toggling class Live Activity tracking
//

import AppIntents
import SwiftUI
import WidgetKit

struct MiddlesexLiveActivityControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.nicholasnoon.Middlesex.MiddlesexLiveActivity",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Class Tracker",
                isOn: value,
                action: ToggleClassTrackerIntent()
            ) { isRunning in
                Label(isRunning ? "Tracking" : "Off", systemImage: isRunning ? "book.fill" : "book.closed")
            }
        }
        .displayName("Class Tracker")
        .description("Toggle live class schedule tracking.")
    }
}

extension MiddlesexLiveActivityControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool {
            false
        }

        func currentValue() async throws -> Bool {
            // Return whether a class Live Activity is currently running
            return false
        }
    }
}

struct ToggleClassTrackerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Class Tracker"

    @Parameter(title: "Tracking enabled")
    var value: Bool

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
