//
//  OnboardingView.swift
//  Middlesex
//
//  Onboarding flow for new users
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var currentPage = 0
    @State private var name = ""
    @State private var grade = ""
    @State private var showingCameraImport = false
    @State private var showingManualBuilder = false
    @State private var redWeekSchedule: [String: [BlockTime]] = [:]
    @State private var whiteWeekSchedule: [String: [BlockTime]] = [:]

    var body: some View {
        ZStack {
            MiddlesexTheme.redGradient
                .ignoresSafeArea()

            VStack {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 40)

                TabView(selection: $currentPage) {
                    WelcomeScreen()
                        .tag(0)

                    UserInfoScreen(name: $name, grade: $grade)
                        .tag(1)

                    ScheduleSetupIntroScreen()
                        .tag(2)

                    ScheduleImportMethodScreen(
                        onCameraImport: {
                            showingCameraImport = true
                        },
                        onManualImport: {
                            showingManualBuilder = true
                        }
                    )
                    .tag(3)

                    SimplifiedScheduleBuilder(onComplete: completeOnboarding)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .sheet(isPresented: $showingCameraImport) {
                CameraScheduleImportView(
                    redWeekSchedule: $redWeekSchedule,
                    whiteWeekSchedule: $whiteWeekSchedule
                )
            }
            .sheet(isPresented: $showingManualBuilder) {
                SimplifiedScheduleBuilder(onComplete: completeOnboarding)
            }
        }
    }

    private func completeOnboarding() {
        preferences.userName = name
        preferences.userGrade = grade
        preferences.completeOnboarding() // Use new method that sets version
    }
}

struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // School logo placeholder (replace with actual logo)
            Image(systemName: "building.columns.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .foregroundColor(.white)

            Text("Welcome to")
                .font(.title2)
                .foregroundColor(.white.opacity(0.9))

            Text("Middlesex")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Text("Your school hub for schedules, menus, announcements, and sports")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Text("Swipe to continue")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 40)
        }
    }
}

struct UserInfoScreen: View {
    @Binding var name: String
    @Binding var grade: String

    let grades = ["9th Grade", "10th Grade", "11th Grade", "12th Grade"]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            Text("Let's get to know you")
                .font(.title.bold())
                .foregroundColor(.white)

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.headline)
                        .foregroundColor(.white)

                    TextField("Enter your name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Grade")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        ForEach(grades, id: \.self) { gradeOption in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    grade = gradeOption
                                }
                            } label: {
                                Text(gradeOption.replacingOccurrences(of: " Grade", with: ""))
                                    .font(.headline)
                                    .foregroundColor(grade == gradeOption ? MiddlesexTheme.primaryRed : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(grade == gradeOption ? Color.white : Color.white.opacity(0.2))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(grade == gradeOption ? 0.3 : 0.1), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("Swipe to continue")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 40)
        }
    }
}

struct ScheduleSetupIntroScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            Text("Red & White Week")
                .font(.title.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 15) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.red)
                    Text("Middlesex uses a Red/White week rotating schedule")
                        .foregroundColor(.white)
                }

                HStack(spacing: 15) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                    Text("You'll set up your classes for each week type")
                        .foregroundColor(.white)
                }

                HStack(spacing: 15) {
                    Image(systemName: "clock")
                        .foregroundColor(.white)
                    Text("Each period has specific start and end times")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            Text("Swipe to set up your schedule")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 40)
        }
    }
}

struct ScheduleImportMethodScreen: View {
    let onCameraImport: () -> Void
    let onManualImport: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "arrow.up.doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.white)

            Text("Import Your Schedule")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("Choose how you'd like to set up your schedule")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 16) {
                // Camera Import Button
                Button(action: onCameraImport) {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                            .frame(width: 50, height: 50)
                            .background(Color.white)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Camera Import")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Take photos of your schedules")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)

                // Manual Import Button
                Button(action: onManualImport) {
                    HStack(spacing: 16) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title2)
                            .foregroundColor(MiddlesexTheme.primaryRed)
                            .frame(width: 50, height: 50)
                            .background(Color.white)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manual Entry")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Select your classes manually")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 30)

            Spacer()

            Text("You can always change your schedule later")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 40)
        }
    }
}

#Preview {
    OnboardingView()
}
