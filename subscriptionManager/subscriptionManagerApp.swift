//
//  subscriptionManagerApp.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import SwiftUI
import UserNotifications
import StoreKit

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Initialize purchase service and check subscription status
        Task {
            await PurchaseService.shared.checkSubscriptionStatus()
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
