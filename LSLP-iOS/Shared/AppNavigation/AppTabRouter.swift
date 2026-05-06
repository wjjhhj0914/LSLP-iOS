//
//  AppTabRouter.swift
//  LSLP-iOS
//
//  Created by Codex on 5/6/26.
//

import Combine
import SwiftUI

enum AppTab: Int {
    case home
    case orders
    case pickup
    case profile
}

@MainActor
final class AppTabRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var currentOrder: ValidatedOrderItem?

    func showOrderDetail(_ order: ValidatedOrderItem) {
        currentOrder = order
        selectedTab = .orders
    }
}

struct MainTabContainerView: View {
    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var appTabRouter: AppTabRouter

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appTabRouter.selectedTab {
                case .home:
                    HomeView()
                case .orders:
                    OrdersTabView()
                case .pickup:
                    PlaceholderTabView(
                        title: "픽업",
                        systemImage: "sparkles",
                        description: "준비 중인 화면입니다."
                    )
                case .profile:
                    PlaceholderTabView(
                        title: "마이",
                        systemImage: "person.fill",
                        description: "준비 중인 화면입니다."
                    )
                }
            }

            RootTabBar(selectedTab: $appTabRouter.selectedTab)
        }
    }
}

private struct OrdersTabView: View {
    @EnvironmentObject private var appTabRouter: AppTabRouter

    var body: some View {
        Group {
            if let order = appTabRouter.currentOrder {
                OrderStatusDetailView(order: order, showsNavigationHeader: false)
            } else {
                PlaceholderTabView(
                    title: "주문내역",
                    systemImage: "doc.text.fill",
                    description: "아직 표시할 주문이 없습니다."
                )
            }
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color(red: 0.52, green: 0.60, blue: 0.44))

                Text(title)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Color(red: 0.22, green: 0.25, blue: 0.20))

                Text(description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 80)
        }
    }
}

private struct RootTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.98))
                .frame(height: 82)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: -4)

            HStack {
                RootTabBarItem(
                    icon: "house.fill",
                    isSelected: selectedTab == .home
                ) {
                    selectedTab = .home
                }
                RootTabBarItem(
                    icon: "doc.text.fill",
                    isSelected: selectedTab == .orders
                ) {
                    selectedTab = .orders
                }

                Spacer()
                    .frame(width: 74)

                RootTabBarItem(
                    icon: "person.3.fill",
                    isSelected: selectedTab == .pickup
                ) {
                    selectedTab = .pickup
                }
                RootTabBarItem(
                    icon: "person.fill",
                    isSelected: selectedTab == .profile
                ) {
                    selectedTab = .profile
                }
            }
            .padding(.horizontal, 34)

            Button {
                selectedTab = .pickup
            } label: {
                Circle()
                    .fill(Color(red: 0.64, green: 0.71, blue: 0.57))
                    .frame(width: 68, height: 68)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .offset(y: -20)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }
}

private struct RootTabBarItem: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    isSelected
                        ? Color(red: 0.49, green: 0.58, blue: 0.43)
                        : Color(red: 0.88, green: 0.88, blue: 0.88)
                )
                .frame(maxWidth: .infinity)
        }
    }
}
