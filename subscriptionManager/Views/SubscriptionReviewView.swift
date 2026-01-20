//
//  SubscriptionReviewView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

/// Premium dark theme review screen for detected subscriptions
struct SubscriptionReviewView: View {

    @ObservedObject var viewModel: InboxViewModel
    let onComplete: () -> Void

    @State private var editingSubscription: Subscription?
    @State private var showingAddSheet = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.1),
                    Color(red: 0.05, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)

                // Subscription list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Summary
                        summaryCard
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)

                        // High confidence section
                        if !viewModel.highConfidenceSubscriptions.isEmpty {
                            sectionHeader("Likely Subscriptions", count: viewModel.highConfidenceSubscriptions.count)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            ForEach(Array(viewModel.highConfidenceSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                PremiumSubscriptionCard(
                                    subscription: subscription,
                                    iconInfo: viewModel.getIconInfo(for: subscription),
                                    onEdit: { editingSubscription = subscription },
                                    onRemove: { viewModel.removeSubscription(subscription) }
                                )
                                .padding(.horizontal, 24)
                                .offset(y: appeared ? 0 : 30)
                                .opacity(appeared ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.2), value: appeared)
                            }
                        }

                        // Medium/Low confidence section
                        if !viewModel.mediumConfidenceSubscriptions.isEmpty {
                            sectionHeader("Maybe Subscriptions", count: viewModel.mediumConfidenceSubscriptions.count)
                                .padding(.horizontal, 24)
                                .padding(.top, 8)

                            ForEach(Array(viewModel.mediumConfidenceSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                PremiumSubscriptionCard(
                                    subscription: subscription,
                                    iconInfo: viewModel.getIconInfo(for: subscription),
                                    onEdit: { editingSubscription = subscription },
                                    onRemove: { viewModel.removeSubscription(subscription) }
                                )
                                .padding(.horizontal, 24)
                                .offset(y: appeared ? 0 : 30)
                                .opacity(appeared ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.05 + 0.3), value: appeared)
                            }
                        }

                        // Empty state
                        if viewModel.subscriptions.isEmpty {
                            emptyState
                                .padding(.top, 40)
                        }
                    }
                    .padding(.bottom, 120)
                }

                Spacer()
            }

            // Bottom button
            VStack {
                Spacer()
                doneButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .sheet(item: $editingSubscription) { subscription in
            PremiumEditSubscriptionSheet(
                subscription: subscription,
                onSave: { name, price, cycle in
                    viewModel.updateSubscription(subscription, name: name, price: price, cycle: cycle)
                    editingSubscription = nil
                },
                onCancel: { editingSubscription = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSubscriptionView(
                onSubscriptionAdded: { subscription in
                    viewModel.addSubscription(subscription)
                },
                currentSubscriptionCount: viewModel.subscriptions.count
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Review")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Add button
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("We found \(viewModel.subscriptions.count) possible subscriptions. Remove any that don't belong.")
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated Monthly")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.55))
                        .textCase(.uppercase)

                    Text(formatCurrency(viewModel.totalMonthlyEstimate))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(viewModel.subscriptions.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("subscriptions")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(white: 0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundColor(Color(white: 0.35))

            VStack(spacing: 8) {
                Text("No subscriptions found")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(white: 0.7))

                Text("Tap + above to add subscriptions manually")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.45))
            }

            Button(action: { showingAddSheet = true }) {
                Text("Add Subscription")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.25, green: 0.52, blue: 0.96))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 4)
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button(action: {
            viewModel.confirmSubscriptions()
            onComplete()
        }) {
            Text("Done")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.62, blue: 0.98),
                                    Color(red: 0.22, green: 0.48, blue: 0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Brand Logo Mapping

/// Maps subscription names to asset image names (case-insensitive)
struct BrandLogoMapper {

    /// Known brand mappings - add more as needed
    private static let brandAssets: [String: String] = [
        "openai": "OpenAILogo",
        "chatgpt": "OpenAILogo",
        "chatgpt plus": "OpenAILogo",
        "spotify": "SpotifyLogo",
        "youtube": "YouTubeLogo",
        "youtube premium": "YouTubeLogo",
        "youtube music": "YouTubeLogo",
        "gmail": "GmailLogo"
    ]

    /// Get asset image name for a subscription name (case-insensitive)
    static func assetName(for subscriptionName: String) -> String? {
        let normalized = subscriptionName.lowercased().trimmingCharacters(in: .whitespaces)

        // Direct match
        if let asset = brandAssets[normalized] {
            return asset
        }

        // Partial match - check if any key is contained in the name
        for (key, asset) in brandAssets {
            if normalized.contains(key) {
                return asset
            }
        }

        return nil
    }

    /// Check if we have an asset for this subscription
    static func hasAsset(for subscriptionName: String) -> Bool {
        return assetName(for: subscriptionName) != nil
    }
}

// MARK: - Premium Subscription Card

struct PremiumSubscriptionCard: View {

    let subscription: Subscription
    let iconInfo: (name: String, color: Color)
    let onEdit: () -> Void
    let onRemove: () -> Void

    private let logoSize: CGFloat = 52
    private var companyLogoAssetName: String? {
        if let company = CompanyLogoService.shared.company(withId: subscription.merchantId),
           let assetName = company.logoAssetName {
            return assetName
        }

        if let company = CompanyLogoService.shared.findCompany(for: subscription.name),
           let assetName = company.logoAssetName {
            return assetName
        }

        return BrandLogoMapper.assetName(for: subscription.name)
    }
    private var senderDomain: String? {
        let trimmed = subscription.senderEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let domain = trimmed.split(separator: "@").last {
            return String(domain)
        }
        return trimmed
    }

    var body: some View {
        HStack(spacing: 16) {
            // Logo with gray circle background (matching onboarding style)
            subscriptionLogo

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(subscription.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subscription.priceWithCycle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(white: 0.85))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())

                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.55))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.16))
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var subscriptionLogo: some View {
        ZStack {
            // Light gray background circle (matching onboarding)
            Circle()
                .fill(Color(red: 0.75, green: 0.77, blue: 0.78))
                .frame(width: logoSize, height: logoSize)

            if subscription.detectionSource == .manual {
                // Manual entries should prefer local assets.
                if let assetName = companyLogoAssetName {
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize * 0.55, height: logoSize * 0.55)
                } else {
                    // Fallback to SF Symbol with colored background
                    Circle()
                        .fill(iconInfo.color)
                        .frame(width: logoSize, height: logoSize)

                    Image(systemName: iconInfo.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            } else if let domain = senderDomain {
                // Detected entries keep metadata-based logos.
                DomainLogoView(
                    domain: domain,
                    size: logoSize * 0.55,
                    cornerRadius: (logoSize * 0.55) / 2,
                    placeholderName: subscription.name,
                    preferRemote: true
                )
            } else if let assetName = companyLogoAssetName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: logoSize * 0.55, height: logoSize * 0.55)
            } else {
                // Fallback to SF Symbol with colored background
                Circle()
                    .fill(iconInfo.color)
                    .frame(width: logoSize, height: logoSize)

                Image(systemName: iconInfo.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: logoSize, height: logoSize)
    }
}

// MARK: - Premium Edit Subscription Sheet

struct PremiumEditSubscriptionSheet: View {

    let subscription: Subscription
    let onSave: (String, Double, BillingCycle) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var priceText: String
    @State private var selectedCycle: BillingCycle

    init(subscription: Subscription, onSave: @escaping (String, Double, BillingCycle) -> Void, onCancel: @escaping () -> Void) {
        self.subscription = subscription
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: subscription.name)
        _priceText = State(initialValue: String(format: "%.2f", subscription.price))
        _selectedCycle = State(initialValue: subscription.billingCycle)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    // Name field
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(white: 0.55))

                        TextField("Subscription name", text: $name)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }

                    // Price field
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Price")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(white: 0.55))

                        HStack {
                            Text("$")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color(white: 0.55))

                            TextField("0.00", text: $priceText)
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .keyboardType(.decimalPad)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                        )
                    }

                    // Billing cycle
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Billing Cycle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(white: 0.55))

                        HStack(spacing: 10) {
                            ForEach(BillingCycle.allCases.filter { $0 != .unknown }, id: \.self) { cycle in
                                Button(action: { selectedCycle = cycle }) {
                                    Text(cycle.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedCycle == cycle ? .white : Color(white: 0.55))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(selectedCycle == cycle ?
                                                      Color(red: 0.25, green: 0.52, blue: 0.96) :
                                                      Color.white.opacity(0.06))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.08), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(Color(white: 0.55))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let price = Double(priceText) ?? subscription.price
                        onSave(name, price, selectedCycle)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.25, green: 0.52, blue: 0.96))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionReviewView(
        viewModel: {
            let vm = InboxViewModel()
            return vm
        }(),
        onComplete: {}
    )
}
