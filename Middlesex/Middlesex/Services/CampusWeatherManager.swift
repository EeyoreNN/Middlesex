//
//  CampusWeatherManager.swift
//  Middlesex
//
//  WeatherKit integration for Middlesex School campus weather
//

import Foundation
import Combine
import WeatherKit
import CoreLocation

@MainActor
class CampusWeatherManager: ObservableObject {
    static let shared = CampusWeatherManager()

    @Published var currentWeather: Weather?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let weatherService = WeatherService.shared

    // Middlesex School location: 1400 Lowell Rd, Concord, MA 01742
    private let campusLocation = CLLocation(
        latitude: 42.4451,
        longitude: -71.3828
    )

    private init() {}

    func fetchWeather() async {
        isLoading = true
        errorMessage = nil

        do {
            let weather = try await weatherService.weather(for: campusLocation)
            self.currentWeather = weather
            print("✅ Weather fetched successfully for Middlesex School")
        } catch let error as NSError {
            print("❌ Failed to fetch weather: \(error)")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")

            if error.domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" {
                self.errorMessage = "WeatherKit not available. Check:\n1. Capability enabled in Xcode\n2. Running on real device or supported sim\n3. Network connection"
            } else {
                self.errorMessage = "Unable to load weather data"
            }
        }

        isLoading = false
    }

    func refreshWeather() {
        Task {
            await fetchWeather()
        }
    }
}
