//
//  ContentView.swift
//  LSLP-iOS
//
//  Created by Hyojung Jang on 4/22/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authSession: AuthSession

    var body: some View {
        Group {
            switch authSession.state {
            case .loading:
                ProgressView("인증 상태 확인 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .authenticated:
                MainTabContainerView()

            case .unauthenticated:
                LoginView(authService: authSession.makeAuthService())
            }
        }
        .task {
            await authSession.restoreSessionIfNeeded()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthSession())
    }
}
