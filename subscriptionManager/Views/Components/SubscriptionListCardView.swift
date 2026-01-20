//
//  SubscriptionListCardView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI
import UIKit

// MARK: - Subscription List Card View

/// A full-width card component for displaying subscriptions in a stacked list.
/// Each card is a rounded rectangle with consistent corner radius.
struct SubscriptionListCardView<T: SubscriptionCardDisplayable>: View {

    // MARK: - Dependencies

    let subscription: T
    let backgroundColor: Color
    let logoImage: String?
    let isLastCard: Bool
    let onTap: () -> Void

    // MARK: - Configuration

    private let cardHeight: CGFloat = 100
    private let cornerRadius: CGFloat = 24
    private let logoSize: CGFloat = 48
    private let logoCornerRadius: CGFloat = 14

    // MARK: - Initializer

    init(
        subscription: T,
        backgroundColor: Color = .white,
        logoImage: String? = nil,
        isLastCard: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.subscription = subscription
        self.backgroundColor = backgroundColor
        self.logoImage = logoImage
        self.isLastCard = isLastCard
        self.onTap = onTap
    }

    // MARK: - Body

    var body: some View {
        Button {
            Haptics.lightImpact()
            onTap()
        } label: {
            content
        }
        .buttonStyle(PressableCardButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left side: Name and price pill
            VStack(alignment: .leading, spacing: 8) {
                titleRow

                pricePill
            }

            Spacer(minLength: 8)

            serviceLogo

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.black.opacity(0.4))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, isLastCard ? 20 : 44)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Title Row

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subscription.displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .layoutPriority(1)

            Text(renewalText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
        }
    }

    // MARK: - Price Pill

    private var pricePill: some View {
        HStack(spacing: 3) {
            Text(subscription.displayPrice)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text("/")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.6))

            Text(subscription.displayBillingCycle.lowercased())
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white)
        )
    }

    // MARK: - Service Logo

    private var serviceLogo: some View {
        Group {
            if let logoImage = logoImage, !logoImage.isEmpty {
                Image(logoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: logoCornerRadius, style: .continuous))
            } else {
                Image(systemName: subscription.displayIconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(width: logoSize, height: logoSize)
                    .background(Color.white.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: logoCornerRadius, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Renewal Text

    private var renewalText: String {
        if let subscription = subscription as? Subscription,
           let nextDate = subscription.nextBillingDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Renews \(formatter.string(from: nextDate))"
        }

        if let days = subscription.daysUntilNextBilling {
            if let computedDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return "Renews \(formatter.string(from: computedDate))"
            }
        }

        return "Renews —"
    }

    // MARK: - Accessibility

    private var accessibilityLabelText: String {
        let name = subscription.displayName
        let priceText = accessibilityPriceText
        let cadenceText = accessibilityCadenceText
        let renewalText = accessibilityRenewalText
        return "\(name), \(priceText) \(cadenceText), \(renewalText)"
    }

    private var accessibilityPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        let spelled = formatter.string(from: NSNumber(value: subscription.displayPriceValue)) ?? ""
        if spelled.isEmpty {
            return subscription.displayPrice
        }
        return "\(spelled) dollars"
    }

    private var accessibilityCadenceText: String {
        switch subscription.displayBillingCycle.lowercased() {
        case "weekly":
            return "per week"
        case "monthly":
            return "per month"
        case "quarterly":
            return "per quarter"
        case "yearly":
            return "per year"
        default:
            return "per cycle"
        }
    }

    private var accessibilityRenewalText: String {
        if let subscription = subscription as? Subscription,
           let nextDate = subscription.nextBillingDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return "renews \(formatter.string(from: nextDate))"
        }

        if let days = subscription.daysUntilNextBilling {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            let spelledDays = formatter.string(from: NSNumber(value: days)) ?? "\(days)"
            if days == 1 {
                return "renews in one day"
            }
            return "renews in \(spelledDays) days"
        }

        return "renews unknown"
    }
}

// MARK: - Pressable Card Button Style

private struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.12 : 0.2),
                radius: configuration.isPressed ? 8 : 12,
                x: 0,
                y: configuration.isPressed ? 4 : 8
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// MARK: - Haptics

private enum Haptics {
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.11, green: 0.11, blue: 0.12)
            .ignoresSafeArea()

        VStack(spacing: 8) {
            SubscriptionListCardView(
                subscription: PreviewSubData(name: "Figma", price: 12.00, icon: "pencil.and.ruler"),
                backgroundColor: Color(red: 0.25, green: 0.52, blue: 0.96)
            )

            SubscriptionListCardView(
                subscription: PreviewSubData(name: "HBO Max", price: 9.99, icon: "play.rectangle.fill"),
                backgroundColor: Color(red: 0.95, green: 0.75, blue: 0.80)
            )

            SubscriptionListCardView(
                subscription: PreviewSubData(name: "Spotify", price: 8.00, icon: "music.note"),
                backgroundColor: Color(red: 0.45, green: 0.82, blue: 0.55)
            )

            SubscriptionListCardView(
                subscription: PreviewSubData(name: "PlayStation Plus", price: 67.57, icon: "gamecontroller.fill"),
                backgroundColor: Color(red: 0.55, green: 0.40, blue: 0.75)
            )

            SubscriptionListCardView(
                subscription: PreviewSubData(name: "YouTube", price: 8.97, icon: "play.circle.fill"),
                backgroundColor: Color(red: 0.95, green: 0.55, blue: 0.35)
            )
        }
    }
}

// MARK: - Preview Helper

private struct PreviewSubData: SubscriptionCardDisplayable {
    let name: String
    let price: Double
    let icon: String

    var displayId: UUID { UUID() }
    var displayName: String { name }
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    var displayPriceValue: Double { price }
    var displayBillingCycle: String { "Monthly" }
    var displayIconName: String { icon }
    var displayIconColor: Color { .black }
    var displayBackgroundColor: Color { .white }
    var daysUntilNextBilling: Int? { nil }
}
