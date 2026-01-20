//
//  NotificationViewModel.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation
import SwiftUI

// MARK: - Notification View Model

@MainActor
final class NotificationViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var notifications: [AppNotification] = []

    // MARK: - Computed Properties

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var hasUnreadNotifications: Bool {
        unreadCount > 0
    }

    // MARK: - Private Properties

    private let storageKey = "appNotifications"
    private let reminderDaysKey = "notification.reminderDays"

    // MARK: - Initialization

    init() {
        loadNotifications()
    }

    // MARK: - Persistence

    /// Load notifications from UserDefaults
    func loadNotifications() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) else {
            notifications = []
            return
        }
        // Sort by renewal date (soonest first), then by creation date
        notifications = decoded.sorted { lhs, rhs in
            if lhs.renewalDate == rhs.renewalDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.renewalDate < rhs.renewalDate
        }
    }

    /// Save notifications to UserDefaults
    private func saveNotifications() {
        guard let encoded = try? JSONEncoder().encode(notifications) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    // MARK: - Notification Generation

    /// Generate in-app notifications for subscriptions with upcoming renewals within the specified days
    /// - Parameter subscriptions: Array of user's subscriptions
    /// - Parameter withinDays: Number of days to look ahead (default: 3)
    func generateNotificationsForUpcomingRenewals(from subscriptions: [Subscription], withinDays: Int = 3) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for subscription in subscriptions {
            guard let renewalDate = subscription.nextBillingDate else { continue }

            let renewalDay = calendar.startOfDay(for: renewalDate)
            let components = calendar.dateComponents([.day], from: today, to: renewalDay)

            guard let daysUntil = components.day, daysUntil >= 0 && daysUntil <= withinDays else {
                continue
            }

            // Check if a notification already exists for this subscription and renewal date
            let existingNotification = notifications.first { notification in
                notification.subscriptionId == subscription.id &&
                calendar.isDate(notification.renewalDate, inSameDayAs: renewalDate)
            }

            if existingNotification == nil {
                // Create a new notification
                let newNotification = AppNotification(
                    subscriptionId: subscription.id,
                    subscriptionName: subscription.name,
                    subscriptionPrice: subscription.price,
                    billingCycle: subscription.billingCycle,
                    renewalDate: renewalDate
                )
                notifications.append(newNotification)
            }
        }

        // Remove old notifications (past renewal dates by more than 1 day)
        notifications = notifications.filter { notification in
            notification.daysUntilRenewal >= -1
        }

        // Sort by renewal date
        notifications.sort { lhs, rhs in
            if lhs.renewalDate == rhs.renewalDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.renewalDate < rhs.renewalDate
        }

        saveNotifications()
    }

    // MARK: - Read State Management

    /// Mark a specific notification as read
    /// - Parameter notification: The notification to mark as read
    func markAsRead(_ notification: AppNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        saveNotifications()
    }

    /// Mark all notifications as read
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        saveNotifications()
    }

    // MARK: - Deletion

    /// Delete a specific notification
    /// - Parameter notification: The notification to delete
    func deleteNotification(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
        saveNotifications()
    }

    /// Delete all notifications
    func clearAllNotifications() {
        notifications.removeAll()
        saveNotifications()
    }

    // MARK: - System Notifications

    /// Schedule system notifications for all subscriptions
    /// - Parameter subscriptions: Array of user's subscriptions
    func scheduleSystemNotifications(for subscriptions: [Subscription]) {
        Task {
            let status = await NotificationService.shared.checkPermissionStatus()
            guard status == .authorized else { return }

            let reminderDays = UserDefaults.standard.array(forKey: reminderDaysKey) as? [Int] ?? [3, 1]
            await NotificationService.shared.scheduleAllNotifications(for: subscriptions, reminderDays: reminderDays)
        }
    }

    /// Request notification permission and schedule notifications if granted
    /// - Parameter subscriptions: Array of user's subscriptions
    func requestPermissionAndSchedule(for subscriptions: [Subscription]) {
        Task {
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                await scheduleSystemNotifications(for: subscriptions)
            }
        }
    }
}
