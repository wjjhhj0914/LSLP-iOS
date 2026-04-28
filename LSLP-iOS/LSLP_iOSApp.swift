//
//  LSLP_iOSApp.swift
//  LSLP-iOS
//
//  Created by Hyojung Jang on 4/22/26.
//

import SwiftUI

@main
struct LSLP_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authSession = AuthSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authSession)
        }
    }
}
