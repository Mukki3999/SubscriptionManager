//
//  AppNotification.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import Foundation

// MARK: - Notification Type

enum AppNotificationType: String, Codable {
    case renewalReminder
}

// MARK: - App Notification Model

struct AppNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let subscriptionId: UUID
    let subscriptionName: String
    let subscriptionPrice: Double
    let billingCycle: BillingCycle
    let renewalDate: Date
    let type: AppNotificationType
    let createdAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        subscriptionId: UUID,
        subscriptionName: String,
        subscriptionPrice: Double,
        billingCycle: BillingCycle,
        renewalDate: Date,
        type: AppNotificationType = .renewalReminder,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.subscriptionId = subscriptionId
        self.subscriptionName = subscriptionName
        self.subscriptionPrice = subscriptionPrice
        self.billingCycle = billingCycle
        self.renewalDate = renewalDate
        self.type = type
        self.createdAt = createdAt
        self.isRead = isRead
    }

    // MARK: - Computed Properties

    var daysUntilRenewal: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let renewal = calendar.startOfDay(for: renewalDate)
        let components = calendar.dateComponents([.day], from: today, to: renewal)
        return components.day ?? 0
    }

    var message: String {
        let days = daysUntilRenewal
        switch days {
        case ...(-1):
            return "Your \(subscriptionName) subscription (\(formattedPrice)) has renewed."
        case 0:
            return "Your \(subscriptionName) subscription (\(formattedPrice)) renews today."
        case 1:
            return "Your \(subscriptionName) subscription (\(formattedPrice)) renews tomorrow."
        default:
            return "Your \(subscriptionName) subscription (\(formattedPrice)) renews in \(days) days."
        }
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let priceString = formatter.string(from: NSNumber(value: subscriptionPrice)) ?? "$\(subscriptionPrice)"
        return "\(priceString)\(billingCycle.shortLabel)"
    }

    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id
    }
}
