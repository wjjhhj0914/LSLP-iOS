//
//  AppDelegate.swift
//  LSLP-iOS
//
//  Created by Codex on 4/28/26.
//

import Foundation
import UIKit
import UserNotifications
import iamport_ios

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  
  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool {
    Iamport.shared.receivedURL(url)
    return true
  }
  
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    requestNotificationAuthorization(for: application)
    
#if canImport(FirebaseCore)
    FirebaseApp.configure()
#endif
    
#if canImport(FirebaseMessaging)
    Messaging.messaging().delegate = self
#else
    print("Firebase Messaging SDK is not linked. Add FirebaseMessaging to receive an FCM token.")
#endif
    
    return true
  }
  
  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
#if canImport(FirebaseMessaging)
    Messaging.messaging().apnsToken = deviceToken
#endif
  }
  
  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  private func requestNotificationAuthorization(for application: UIApplication) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error {
        print("Notification authorization request failed: \(error.localizedDescription)")
      } else {
        print("Notification authorization granted: \(granted)")
      }
      
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
  }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let fcmToken, !fcmToken.isEmpty else {
      print("FCM registration token is empty.")
      return
    }
    
    print("FCM registration token: \(fcmToken)")
  }
}
#endif
