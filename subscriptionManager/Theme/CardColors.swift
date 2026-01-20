//
//  CardColors.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/16/26.
//

import SwiftUI

// MARK: - Subscription Card Colors

/// Centralized color palette for subscription cards.
/// Colors are softened/pastel variants (~25% reduced saturation) for better visual comfort in dark mode.
enum SubscriptionCardColors {

    // MARK: - Primary Card Colors (Softened)

    /// Soft sky blue - primary accent color
    static let softBlue = Color(red: 0.50, green: 0.68, blue: 0.92)

    /// Soft butter yellow - secondary accent
    static let softYellow = Color(red: 0.95, green: 0.90, blue: 0.55)

    /// Dusty rose pink
    static let softPink = Color(red: 0.92, green: 0.78, blue: 0.85)

    /// Soft sage green
    static let softGreen = Color(red: 0.65, green: 0.85, blue: 0.72)

    /// Soft lavender purple
    static let softPurple = Color(red: 0.72, green: 0.68, blue: 0.85)

    /// Soft peach orange
    static let softOrange = Color(red: 0.92, green: 0.75, blue: 0.62)

    // MARK: - Card Color Rotation

    /// Ordered array of card colors for cycling through subscriptions
    static let cardRotation: [Color] = [
        softBlue,
        softYellow,
        softPink,
        softGreen,
        softPurple,
        softOrange
    ]

    /// Returns a color for a given index, cycling through the palette
    static func color(for index: Int) -> Color {
        cardRotation[index % cardRotation.count]
    }

    // MARK: - Upcoming Bill Glass Style

    /// Dark glass base color for upcoming bill cards
    static let glassBase = Color(red: 0.16, green: 0.16, blue: 0.18)

    /// Slightly lighter glass for subtle variation
    static let glassLight = Color(red: 0.20, green: 0.20, blue: 0.22)

    /// Glass border/stroke color
    static let glassBorder = Color.white.opacity(0.08)

    /// Returns dark glass color for all upcoming bills (unified style)
    static func upcomingColor(for index: Int) -> Color {
        glassBase
    }
}
