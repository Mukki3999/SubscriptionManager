//
//  NotificationService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation
import UserNotifications

// MARK: - Notification Service

final class NotificationService {

    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission Management

    /// Request notification authorization from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("NotificationService: Error requesting permission - \(error.localizedDescription)")
            return false
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule Notifications

    /// Schedule a renewal notification for a subscription
    /// - Parameters:
    ///   - subscription: The subscription to notify about
    ///   - daysBeforeRenewal: Number of days before renewal to send notification
    func scheduleRenewalNotification(for subscription: Subscription, daysBeforeRenewal: Int) async {
        guard let renewalDate = subscription.nextBillingDate else { return }

        // Calculate notification date (at 9 AM)
        let calendar = Calendar.current
        guard let notificationDate = calendar.date(byAdding: .day, value: -daysBeforeRenewal, to: renewalDate) else {
            return
        }

        // Don't schedule if the notification date is in the past
        let now = Date()
        var scheduledDate = notificationDate

        // Set time to 9 AM
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        components.hour = 9
        components.minute = 0
        components.second = 0

        guard let finalDate = calendar.date(from: components), finalDate > now else {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewal"

        let daysText: String
        switch daysBeforeRenewal {
        case 0:
            daysText = "today"
        case 1:
            daysText = "tomorrow"
        default:
            daysText = "in \(daysBeforeRenewal) days"
        }

        content.body = "Your \(subscription.name) subscription (\(subscription.priceWithCycle)) renews \(daysText)."
        content.sound = .default
        content.userInfo = [
            "subscriptionId": subscription.id.uuidString,
            "subscriptionName": subscription.name
        ]

        // Create trigger
        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: finalDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        // Create request with unique identifier
        let identifier = "\(subscription.id.uuidString)-\(daysBeforeRenewal)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Schedule the notification
        do {
            try await notificationCenter.add(request)
            print("NotificationService: Scheduled notification for \(subscription.name) at \(finalDate)")
        } catch {
            print("NotificationService: Failed to schedule notification - \(error.localizedDescription)")
        }
    }

    /// Schedule notifications for all subscriptions at specified reminder days
    /// - Parameters:
    ///   - subscriptions: Array of subscriptions to schedule notifications for
    ///   - reminderDays: Array of days before renewal to send notifications (default: [3, 1])
    func scheduleAllNotifications(for subscriptions: [Subscription], reminderDays: [Int] = [3, 1]) async {
        // First, remove all pending notifications
        notificationCenter.removeAllPendingNotificationRequests()

        // Schedule new notifications for each subscription
        for subscription in subscriptions {
            guard subscription.nextBillingDate != nil else { continue }

            for days in reminderDays {
                await scheduleRenewalNotification(for: subscription, daysBeforeRenewal: days)
            }
        }
    }

    // MARK: - Remove Notifications

    /// Remove all scheduled notifications for a specific subscription
    /// - Parameter subscription: The subscription to remove notifications for
    func removeNotifications(for subscription: Subscription) {
        let identifiers = [
            "\(subscription.id.uuidString)-1",
            "\(subscription.id.uuidString)-3"
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("NotificationService: Removed notifications for \(subscription.name)")
    }

    /// Remove all pending notifications
    func removeAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("NotificationService: Removed all pending notifications")
    }
}
