//
//  CustomTabBar.swift
//  Middlesex
//
//  Custom tab bar with center logo button
//

import SwiftUI

enum TabItem: String, CaseIterable {
    case menu = "Menu"
    case schedule = "Schedule"
    case home = "Home"
    case announcements = "Announcements"
    case sports = "Sports"

    var icon: String {
        switch self {
        case .menu: return "fork.knife"
        case .schedule: return "calendar"
        case .home: return "building.columns.fill"
        case .announcements: return "megaphone.fill"
        case .sports: return "figure.run"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                if tab == .home {
                    // Center logo button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [MiddlesexTheme.primaryRed, MiddlesexTheme.primaryRed.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .shadow(color: MiddlesexTheme.primaryRed.opacity(0.4), radius: 8, x: 0, y: 4)

                            Image(systemName: tab.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .offset(y: -15)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Regular tab items
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22))
                                .frame(height: 24)

                            Text(tab.rawValue)
                                .font(.caption2)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                        }
                        .foregroundColor(selectedTab == tab ? MiddlesexTheme.primaryRed : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(MiddlesexTheme.primaryRed.opacity(0.1))
                                        .matchedGeometryEffect(id: "TAB", in: animation)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .frame(maxWidth: .infinity)
    }
}

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @StateObject private var cloudKitManager = CloudKitManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                if selectedTab == .menu {
                    MenuView()
                } else if selectedTab == .schedule {
                    ScheduleView()
                } else if selectedTab == .home {
                    HomeView()
                } else if selectedTab == .announcements {
                    AnnouncementsView()
                } else if selectedTab == .sports {
                    SportsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .task {
            await cloudKitManager.refreshAllData()
        }
    }
}

#Preview {
    MainTabView()
}
