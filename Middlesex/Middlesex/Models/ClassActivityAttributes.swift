//
//  ClassActivityAttributes.swift
//  Middlesex
//
//  Shared Live Activity attributes accessible by both app and widget extension
//

import Foundation
import ActivityKit

struct ClassActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic properties that update during class
        var timeRemaining: TimeInterval
        var progress: Double // 0.0 to 1.0
        var currentTime: Date
        var startDate: Date
        var endDate: Date
    }

    // Fixed properties for the class
    var className: String
    var teacher: String
    var room: String
    var block: String
    var startTime: String
    var endTime: String
    var classColor: String // Hex color
}
