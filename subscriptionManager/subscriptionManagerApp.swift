//
//  subscriptionManagerApp.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import SwiftUI
import UserNotifications
import StoreKit
import FirebaseCore
import RevenueCat

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Configure RevenueCat SDK (before any purchase operations)
        RevenueCatPurchaseService.shared.configure()

        // Clear stale Keychain data on fresh install
        // UserDefaults are deleted on app uninstall, but Keychain persists
        // This ensures a clean state after reinstall
        let hasLaunchedKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            KeychainService.shared.clearAll()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }

        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Initialize purchase service and check subscription status
        Task {
            await RevenueCatPurchaseService.shared.checkSubscriptionStatus()
        }

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract subscription info if available
        if let subscriptionIdString = userInfo["subscriptionId"] as? String,
           let subscriptionId = UUID(uuidString: subscriptionIdString) {
            // Post notification to navigate to subscription
            NotificationCenter.default.post(
                name: .didTapSubscriptionNotification,
                object: nil,
                userInfo: ["subscriptionId": subscriptionId]
            )
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didTapSubscriptionNotification = Notification.Name("didTapSubscriptionNotification")
}

// MARK: - App

@main
struct subscriptionManagerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
