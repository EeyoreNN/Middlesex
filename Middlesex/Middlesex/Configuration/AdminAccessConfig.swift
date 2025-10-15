//
//  AdminAccessConfig.swift
//  Middlesex
//
//  Centralized configuration for admin access and permanent codes.
//

import Foundation

enum AdminAccessConfig {
    /// Single-use master code that permanently elevates the first claimant.
    /// Replace with the real secret before shipping.
    static let permanentAdminCode = "72357235"

    /// Legacy display names that should retain code-generator access (e.g. seeded accounts).
    static let legacyCodeGeneratorNames: Set<String> = ["Nick Noon"]
}
