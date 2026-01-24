//
//  AllUpcomingBillsView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/21/26.
//

import SwiftUI

struct AllUpcomingBillsView: View {

    let subscriptions: [Subscription]
    let colorIndices: [UUID: Int]
    var onSelectSubscription: ((Subscription) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private let darkBackground = Color(red: 0.11, green: 0.11, blue: 0.12)

    var body: some View {
        NavigationStack {
            ZStack {
                darkBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedSubscriptions) { subscription in
                            UpcomingBillRow(
                                subscription: subscription,
                                cardColor: cardColor(for: subscription.id),
                                logoImage: SubscriptionLogoResolver.assetName(for: subscription)
                            )
                            .onTapGesture {
                                onSelectSubscription?(subscription)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Upcoming Bills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(darkBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private var sortedSubscriptions: [Subscription] {
        subscriptions
            .sorted { ($0.nextBillingDate ?? .distantFuture) < ($1.nextBillingDate ?? .distantFuture) }
    }

    private func cardColor(for id: UUID) -> Color {
        let index = colorIndices[id] ?? 0
        return SubscriptionCardColors.color(for: index)
    }
}

// MARK: - Upcoming Bill Row

private struct UpcomingBillRow: View {

    let subscription: Subscription
    let cardColor: Color
    let logoImage: String?

    private let logoSize: CGFloat = 52
    private let logoCornerRadius: CGFloat = 14

    var body: some View {
        HStack(spacing: 14) {
            // Logo - matches notification view styling
            if let logoName = logoImage, !logoName.isEmpty {
                Image(logoName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: logoCornerRadius, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: logoCornerRadius, style: .continuous)
                        .fill(Color.white)
                        .frame(width: logoSize, height: logoSize)

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                }
            }

            // Name and billing cycle
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)

                Text(subscription.billingCycle.rawValue)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.5))
            }

            Spacer()

            // Price and days left
            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.formattedPrice)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)

                if let daysLeft = subscription.daysUntilNextBilling {
                    Text(daysLeftText(daysLeft))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(daysLeftColor(daysLeft))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardColor)
        )
    }

    private func daysLeftText(_ days: Int) -> String {
        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "in \(days) days"
        }
    }

    private func daysLeftColor(_ days: Int) -> Color {
        if days <= 3 {
            return Color.red
        } else if days <= 7 {
            return Color.orange
        } else {
            return Color.black.opacity(0.5)
        }
    }
}

#Preview {
    AllUpcomingBillsView(
        subscriptions: [
            Subscription(
                merchantId: "spotify",
                name: "Spotify",
                price: 18.00,
                billingCycle: .monthly,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
                senderEmail: "no-reply@spotify.com"
            ),
            Subscription(
                merchantId: "netflix",
                name: "Netflix",
                price: 21.00,
                billingCycle: .monthly,
                nextBillingDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                senderEmail: "info@netflix.com"
            )
        ],
        colorIndices: [:]
    )
}
