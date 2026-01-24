//
//  BalanceCardView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

// MARK: - Balance Card View

/// A glassmorphism-style card displaying the user's monthly subscription balance
/// with an integrated donut chart showing spending distribution.
struct BalanceCardView: View {

    // MARK: - Dependencies

    let balance: Double
    let billingDate: String
    @Binding var isBalanceHidden: Bool

    /// Chart items built from subscription data
    let chartItems: [LogoDonutItem]

    /// Whether user has Pro access (determines navigation vs paywall behavior)
    let isPro: Bool

    /// Called when user taps the chart area
    let onChartTap: () -> Void

    // MARK: - Configuration

    private let cornerRadius: CGFloat = 16

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main content
            HStack(alignment: .center, spacing: 0) {
                // Left side: Labels and balance
                leftContent

                Spacer(minLength: 0)

                // Right side: Donut chart with PRO badge + chevron (tappable)
                chartArea
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)

            // Eye button in top-right corner
            eyeButton
                .padding(.top, 14)
                .padding(.trailing, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onChartTap()
        }
    }

    // MARK: - Left Content

    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            Text("Monthly spend")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.5))

            // Balance amount
            Text(isBalanceHidden ? "••••••" : formattedBalance)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            // Billing date
            Text("Next bill: \(billingDate)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Chart Area

    private var chartArea: some View {
        chartWithBadge
            .padding(.trailing, 40)
            .accessibilityLabel(isPro ? "Spending breakdown" : "Spending breakdown. Pro feature.")
    }

    // MARK: - Chart with PRO Badge

    private var chartWithBadge: some View {
        ZStack(alignment: .topTrailing) {
            LogoDonutChartView(
                items: chartItems,
                lineWidth: 18,
                size: 78,
                showLogos: false
            )
            if !isPro {
                proBadge
                    .offset(x: 6, y: -6)
            }
        }
        .frame(width: 90, height: 90) // Fixed frame to accommodate badge offset
    }

    // MARK: - PRO Badge

    private var proBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PRO")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(red: 0.78, green: 0.93, blue: 0.87)))
    }

    // MARK: - Eye Button

    private var eyeButton: some View {
        Button(action: { isBalanceHidden.toggle() }) {
            Image(systemName: isBalanceHidden ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isBalanceHidden)
    }

    // MARK: - Computed Properties

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: balance)) ?? "$\(balance)"
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.11, green: 0.11, blue: 0.12)
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // With multiple subscriptions
            BalanceCardView(
                balance: 77.00,
                billingDate: "01/31",
                isBalanceHidden: .constant(false),
                chartItems: [
                    LogoDonutItem(id: UUID(), name: "Netflix", value: 15.99, color: ChartColors.mutedBlue, logoName: "NetflixLogo"),
                    LogoDonutItem(id: UUID(), name: "Spotify", value: 9.99, color: ChartColors.mutedGreen, logoName: "SpotifyLogo 1"),
                    LogoDonutItem(id: UUID(), name: "Disney+", value: 7.99, color: ChartColors.mutedPink, logoName: "DisneyPlusLogo"),
                    LogoDonutItem(id: UUID(), name: "HBO", value: 14.99, color: ChartColors.mutedPurple, logoName: "MaxLogo")
                ],
                isPro: false,
                onChartTap: { print("Chart tapped") }
            )

            // Empty state (no subscriptions)
            BalanceCardView(
                balance: 0,
                billingDate: "01/31",
                isBalanceHidden: .constant(false),
                chartItems: [],
                isPro: false,
                onChartTap: { print("Chart tapped") }
            )
        }
        .padding(.horizontal, 24)
    }
}
