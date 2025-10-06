//
//  ExtracurricularInfo.swift
//  Middlesex
//
//  Extracurricular activities and positions
//

import Foundation
import SwiftUI

struct ExtracurricularInfo: Codable {
    var isInSmallChorus: Bool
    var isInChapelChorus: Bool
    var senatePosition: SenatePosition?

    enum SenatePosition: String, Codable, CaseIterable {
        case classPresident = "Class President"
        case dormRepresentative = "Dorm Representative"
        case none = "Not in Senate"

        var displayName: String {
            rawValue
        }
    }
}

// Extension to UserPreferences to store extracurricular info
extension UserPreferences {
    private var extracurricularKey: String { "extracurricularInfo" }

    var extracurricularInfo: ExtracurricularInfo {
        get {
            if let data = UserDefaults.standard.data(forKey: extracurricularKey),
               let decoded = try? JSONDecoder().decode(ExtracurricularInfo.self, from: data) {
                return decoded
            }
            return ExtracurricularInfo(isInSmallChorus: false, isInChapelChorus: false, senatePosition: ExtracurricularInfo.SenatePosition.none)
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: extracurricularKey)
            }
        }
    }
}
