//
//  SubscriptionCardDisplayable.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

// MARK: - Subscription Card Displayable Protocol

/// Protocol defining the data contract for subscription card display.
/// This enables dependency injection and allows any conforming type to be rendered by our card components.
protocol SubscriptionCardDisplayable {
    var displayId: UUID { get }
    var displayName: String { get }
    var displayPrice: String { get }
    var displayPriceValue: Double { get }
    var displayBillingCycle: String { get }
    var displayIconName: String { get }
    var displayIconColor: Color { get }
    var displayBackgroundColor: Color { get }
    var daysUntilNextBilling: Int? { get }
}

// MARK: - Subscription Conformance

extension Subscription: SubscriptionCardDisplayable {
    var displayId: UUID { id }
    var displayName: String { name }
    var displayPrice: String { formattedPrice }
    var displayPriceValue: Double { price }
    var displayBillingCycle: String { billingCycle.rawValue }
    var displayIconName: String { "creditcard.fill" }
    var displayIconColor: Color { .gray }
    var displayBackgroundColor: Color { .white }

    var daysUntilNextBilling: Int? {
        guard let nextDate = nextBillingDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDate)
        return components.day
    }
}

// MARK: - Card Configuration

/// Configuration object for customizing card appearance
struct SubscriptionCardConfiguration {
    let showBillingCycle: Bool
    let showDaysLeft: Bool
    let cardStyle: CardStyle
    let iconSize: CGFloat
    let showAddButton: Bool

    enum CardStyle {
        case list       // Standard list row style
        case compact    // Compact horizontal scroll style
        case featured   // Large featured card style
    }

    static let listDefault = SubscriptionCardConfiguration(
        showBillingCycle: true,
        showDaysLeft: false,
        cardStyle: .list,
        iconSize: 44,
        showAddButton: false
    )

    static let upcomingBill = SubscriptionCardConfiguration(
        showBillingCycle: false,
        showDaysLeft: true,
        cardStyle: .compact,
        iconSize: 36,
        showAddButton: false
    )

    static let subscriptionRow = SubscriptionCardConfiguration(
        showBillingCycle: true,
        showDaysLeft: false,
        cardStyle: .list,
        iconSize: 44,
        showAddButton: true
    )
}

// MARK: - Card Color Palette

/// Predefined color palette for subscription cards.
/// Uses centralized colors from SubscriptionCardColors for consistency.
enum SubscriptionCardColor: CaseIterable {
    case yellow
    case lavender
    case mint
    case peach
    case skyBlue
    case coral

    var backgroundColor: Color {
        switch self {
        case .yellow: return SubscriptionCardColors.softYellow
        case .lavender: return SubscriptionCardColors.softPurple
        case .mint: return SubscriptionCardColors.softGreen
        case .peach: return SubscriptionCardColors.softOrange
        case .skyBlue: return SubscriptionCardColors.softBlue
        case .coral: return SubscriptionCardColors.softPink
        }
    }

    static func color(for index: Int) -> SubscriptionCardColor {
        let colors = Self.allCases
        return colors[index % colors.count]
    }
}
