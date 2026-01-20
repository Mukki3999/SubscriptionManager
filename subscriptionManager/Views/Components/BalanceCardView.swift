//
//  BalanceCardView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

// MARK: - Balance Card View

/// A glassmorphism-style card displaying the user's monthly subscription balance.
/// Matches the dark elevated card design from the reference.
struct BalanceCardView: View {

    // MARK: - Dependencies

    let balance: Double
    let billingDate: String
    @Binding var isBalanceHidden: Bool

    // MARK: - Configuration

    private let cornerRadius: CGFloat = 16

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Label and eye button
            HStack {
                Text("Monthly spend")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                eyeButton
            }

            // Bottom row: Balance and date
            HStack(alignment: .bottom) {
                // Balance amount
                Text(isBalanceHidden ? "••••••" : formattedBalance)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Billing date
                Text("Next bill: \(billingDate)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
        )
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
            BalanceCardView(
                balance: 568.87,
                billingDate: "06/30",
                isBalanceHidden: .constant(false)
            )

            BalanceCardView(
                balance: 568.87,
                billingDate: "06/30",
                isBalanceHidden: .constant(true)
            )
        }
        .padding(.horizontal, 24)
    }
}
