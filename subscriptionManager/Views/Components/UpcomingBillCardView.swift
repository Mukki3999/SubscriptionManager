//
//  UpcomingBillCardView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

// MARK: - Upcoming Bill Card View

/// A compact card for the horizontal "Upcoming Bill" scroll section.
/// Matches the reference design with icon top-left, price/days top-right, name bottom-left.
struct UpcomingBillCardView<T: SubscriptionCardDisplayable>: View {

    // MARK: - Dependencies

    let subscription: T
    let backgroundColor: Color
    let daysLeft: Int
    let logoImage: String?

    // MARK: - Configuration

    private let cardWidth: CGFloat = 140
    private let cardHeight: CGFloat = 120
    private let cornerRadius: CGFloat = 20
    private let iconSize: CGFloat = 40
    private let iconCornerRadius: CGFloat = 12

    // MARK: - Initializer

    init(subscription: T, backgroundColor: Color, daysLeft: Int, logoImage: String? = nil) {
        self.subscription = subscription
        self.backgroundColor = backgroundColor
        self.daysLeft = daysLeft
        self.logoImage = logoImage
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: Icon left, Price/Days right
            HStack(alignment: .top, spacing: 0) {
                // Service icon/logo
                serviceLogo

                Spacer()

                // Price and days left
                VStack(alignment: .trailing, spacing: 2) {
                    Text(subscription.displayPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(textColor)

                    Text("\(daysLeft) days left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                }
            }

            Spacer()

            // Service name at bottom
            Text(subscription.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isDarkCard ? SubscriptionCardColors.glassBorder : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Computed Colors

    private var isDarkCard: Bool {
        // Check if background is dark (for Spotify-style dark card)
        let components = UIColor(backgroundColor).cgColor.components ?? [0, 0, 0, 1]
        let brightness = (components[0] + components[1] + components[2]) / 3
        return brightness < 0.3
    }

    private var textColor: Color {
        isDarkCard ? .white : .black
    }

    private var iconBackgroundColor: Color {
        isDarkCard ? Color.black : Color.white
    }

    private var iconForegroundColor: Color {
        isDarkCard ? Color(red: 0.12, green: 0.84, blue: 0.38) : .black // Spotify green for dark, black for light
    }

    // MARK: - Service Logo

    private var serviceLogo: some View {
        Group {
            if let logoImage = logoImage, !logoImage.isEmpty {
                Image(logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
                        .fill(iconBackgroundColor)
                        .frame(width: iconSize, height: iconSize)

                    Image(systemName: subscription.displayIconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconForegroundColor)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.11, green: 0.11, blue: 0.12)
            .ignoresSafeArea()

        HStack(spacing: 12) {
            // First card: dark glass (featured)
            UpcomingBillCardView(
                subscription: PreviewBillData(name: "Spotify", price: 18.00, icon: "music.note"),
                backgroundColor: SubscriptionCardColors.glassBase,
                daysLeft: 12
            )

            // Rest: match subscription colors
            UpcomingBillCardView(
                subscription: PreviewBillData(name: "Netflix", price: 21.00, icon: "play.rectangle.fill"),
                backgroundColor: SubscriptionCardColors.softYellow,
                daysLeft: 14
            )

            UpcomingBillCardView(
                subscription: PreviewBillData(name: "Apple TV", price: 12.00, icon: "apple.logo"),
                backgroundColor: SubscriptionCardColors.softPink,
                daysLeft: 12
            )
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview Helper

private struct PreviewBillData: SubscriptionCardDisplayable {
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
    var daysUntilNextBilling: Int? { 12 }
}
