//
//  CampusWeatherCard.swift
//  Middlesex
//
//  Weather card showing current campus weather conditions
//

import SwiftUI
import WeatherKit

struct CampusWeatherCard: View {
    @ObservedObject var weatherManager: CampusWeatherManager
    @StateObject private var preferences = UserPreferences.shared

    private func formatTemp(_ celsius: Double) -> String {
        if preferences.prefersCelsius {
            return "\(Int(celsius))°C"
        } else {
            let fahrenheit = (celsius * 9/5) + 32
            return "\(Int(fahrenheit))°F"
        }
    }

    private func formatWind(_ speedKph: Double) -> String {
        if preferences.prefersCelsius {
            return "\(Int(speedKph)) km/h"
        } else {
            let mph = speedKph * 0.621371
            return "\(Int(mph)) mph"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .font(.title2)
                    .foregroundColor(MiddlesexTheme.primaryRed)
                Text("Campus Weather")
                    .font(.headline)
                Spacer()
                Button {
                    weatherManager.refreshWeather()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if weatherManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let error = weatherManager.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
            } else if let weather = weatherManager.currentWeather {
                HStack(spacing: 20) {
                    // Temperature
                    VStack(alignment: .leading) {
                        Text(formatTemp(weather.currentWeather.temperature.value))
                            .font(.system(size: 48, weight: .bold))
                        Text(weather.currentWeather.condition.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Additional details
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack {
                            Image(systemName: "wind")
                                .foregroundColor(.secondary)
                            Text(formatWind(weather.currentWeather.wind.speed.value))
                                .font(.subheadline)
                        }

                        HStack {
                            Image(systemName: "humidity.fill")
                                .foregroundColor(.secondary)
                            Text("\(Int(weather.currentWeather.humidity * 100))%")
                                .font(.subheadline)
                        }

                        HStack {
                            Image(systemName: "thermometer")
                                .foregroundColor(.secondary)
                            Text("Feels like \(formatTemp(weather.currentWeather.apparentTemperature.value))")
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                Text("Tap to load weather")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
