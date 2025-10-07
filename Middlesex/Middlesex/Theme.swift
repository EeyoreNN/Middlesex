//
//  Theme.swift
//  Middlesex
//
//  School color theme configuration
//

import SwiftUI

struct MiddlesexTheme {
    // Primary school colors
    static let primaryRed = Color(red: 200/255, green: 16/255, blue: 46/255) // Middlesex Red
    static let primaryWhite = Color.white
    static let secondaryGray = Color(red: 240/255, green: 240/255, blue: 240/255)

    // Adaptive text colors (works in both light and dark mode)
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // Legacy (for backwards compatibility)
    static let textDark = Color(UIColor.label)
    static let textLight = Color.white

    // Red/White week colors
    static let redWeekColor = Color(red: 220/255, green: 36/255, blue: 66/255)
    static let whiteWeekColor = Color(red: 100/255, green: 100/255, blue: 100/255)

    // Accent colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    // Background colors
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)

    // Gradient backgrounds
    static let redGradient = LinearGradient(
        colors: [primaryRed, primaryRed.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let whiteGradient = LinearGradient(
        colors: [primaryWhite, secondaryGray],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Adaptive card background
    static let cardBackground = Color(UIColor.secondarySystemBackground)
}

// Extension for consistent styling
extension View {
    func middlesexCard() -> some View {
        self
            .background(MiddlesexTheme.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    func middlesexButton() -> some View {
        self
            .padding()
            .background(MiddlesexTheme.primaryRed)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}
