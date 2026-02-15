//
//  PaywallView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/19/26.
//

import SwiftUI
import StoreKit

// MARK: - Social Proof Data

struct SocialProofItem: Identifiable {
    let id = UUID()
    let name: String
    let message: String
    let highlightedAmount: String
    let imageName: String
}

private let socialProofItems: [SocialProofItem] = [
    SocialProofItem(
        name: "Sarah",
        message: " saved ",
        highlightedAmount: "$240/year",
        imageName: "girl1"
    ),
    SocialProofItem(
        name: "Mike",
        message: " cancelled ",
        highlightedAmount: "3 unused subs",
        imageName: "guy1"
    ),
    SocialProofItem(
        name: "Emily",
        message: " avoided a ",
        highlightedAmount: "$15.99 charge",
        imageName: "girl2"
    ),
    SocialProofItem(
        name: "James",
        message: " found ",
        highlightedAmount: "5 hidden subs",
        imageName: "guy2"
    ),
]

// MARK: - Custom Paywall View

/// Custom paywall UI for the control group in A/B testing
struct CustomPaywallView: View {

    @ObservedObject var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    let onContinueFree: (() -> Void)?
    let onPurchaseSuccess: (() -> Void)?

    // Social proof carousel state
    @State private var currentSocialProofIndex = 0
    private let socialProofTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    // MARK: - Theme

    private let backgroundColor = Color(red: 0.06, green: 0.06, blue: 0.07)
    private let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.13)
    private let accentColor = Color(red: 0.6, green: 0.95, blue: 0.7)

    // MARK: - Initialization

    init(
        viewModel: PaywallViewModel,
        onContinueFree: (() -> Void)? = nil,
        onPurchaseSuccess: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onContinueFree = onContinueFree
        self.onPurchaseSuccess = onPurchaseSuccess
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        AnalyticsService.event("paywall_close", params: paywallAnalyticsParams)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer().frame(height: 20)

                // Social proof carousel
                socialProofCarousel
                    .onReceive(socialProofTimer) { _ in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentSocialProofIndex = (currentSocialProofIndex + 1) % socialProofItems.count
                        }
                    }

                Spacer().frame(height: 28)

                // Headline
                Text("Take Control of\nYour Subscriptions")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 32)

                // Features card
                featuresCard

                Spacer().frame(height: 28)

                // Plan selection
                planSelection

                Spacer().frame(height: 20)

                // Free trial text
                if viewModel.hasFreeTrial {
                    HStack(spacing: 6) {
                        Text("7-day free trial")
                            .foregroundColor(.white)
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text("Cancel anytime")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .font(.system(size: 14, weight: .medium))
                }

                Spacer().frame(height: 16)

                // CTA Button
                ctaButton

                Spacer().frame(height: 14)

                // Continue free
                if onContinueFree != nil {
                    Button {
                        AnalyticsService.event("paywall_continue_free", params: paywallAnalyticsParams)
                        onContinueFree?()
                        dismiss()
                    } label: {
                        Text("Continue with free version")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Footer
                VStack(spacing: 10) {
                    Button {
                        Task { await viewModel.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    HStack(spacing: 16) {
                        Link("Terms", destination: URL(string: "https://sparkly-flat-825.notion.site/Terms-of-Service-Trackit-2f3c24ebe50e80b8a67acfe3310d31d4")!)
                        Text("•")
                        Link("Privacy", destination: URL(string: "https://sparkly-flat-825.notion.site/Privacy-Policy-Trackit-2f3c24ebe50e8033b1fae997507127cd?pvs=74")!)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                }
                .padding(.bottom, 16)
            }
        }
        .task {
            await viewModel.loadProductsIfNeeded()
        }
        .onChange(of: viewModel.purchaseSuccessful) { _, success in
            if success {
                onPurchaseSuccess?()
                dismiss()
            }
        }
        .onAppear {
            AnalyticsService.screen("paywall")
            AnalyticsService.event("paywall_view", params: paywallAnalyticsParams)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .disabled(viewModel.isLoading)
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }

    private var paywallAnalyticsParams: [String: Any] {
        var params: [String: Any] = [
            "trigger": viewModel.trigger.analyticsValue,
            "selected_plan": viewModel.selectedPlan.analyticsValue
        ]

        if let detectedSubscriptionCount = viewModel.detectedSubscriptionCount {
            params["detected_subscription_count"] = detectedSubscriptionCount
        }

        if case .featureGate(let feature) = viewModel.trigger {
            params["feature"] = feature
        }

        return params
    }

    // MARK: - Social Proof Carousel

    private var socialProofCarousel: some View {
        let item = socialProofItems[currentSocialProofIndex]

        return HStack(spacing: 12) {
            // Avatar
            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            // Message
            (Text(item.name)
                .fontWeight(.semibold)
             + Text(item.message)
                .foregroundColor(.white.opacity(0.7))
             + Text(item.highlightedAmount)
                .fontWeight(.semibold)
                .foregroundColor(accentColor))
                .font(.system(size: 13))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .id(currentSocialProofIndex) // Force view refresh for animation
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
    }

    // MARK: - Features Card

    private var featuresCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.proFeatures.enumerated()), id: \.element.title) { index, feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 24)

                    Text(feature.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.vertical, 14)

                if index < viewModel.proFeatures.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.06))
                }
            }
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Plan Selection

    private var planSelection: some View {
        HStack(spacing: 12) {
            // Annual plan
            planOption(
                plan: .annual,
                isSelected: viewModel.selectedPlan == .annual,
                showBadge: true
            )

            // Monthly plan
            planOption(
                plan: .monthly,
                isSelected: viewModel.selectedPlan == .monthly,
                showBadge: false
            )
        }
        .padding(.horizontal, 24)
    }

    private func planOption(plan: PremiumProduct, isSelected: Bool, showBadge: Bool) -> some View {
        Button {
            var params: [String: Any] = [
                "trigger": viewModel.trigger.analyticsValue,
                "selected_plan": plan.analyticsValue
            ]
            if let detectedSubscriptionCount = viewModel.detectedSubscriptionCount {
                params["detected_subscription_count"] = detectedSubscriptionCount
            }
            if case .featureGate(let feature) = viewModel.trigger {
                params["feature"] = feature
            }
            AnalyticsService.event("paywall_plan_selected", params: params)
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedPlan = plan
            }
        } label: {
            VStack(spacing: 4) {
                if showBadge {
                    Text("SAVE 33%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 17)
                }

                Text(plan == .annual ? "Annual" : "Monthly")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text(viewModel.formattedPrice(for: plan) ?? "—")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(viewModel.periodSuffix(for: plan))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                if plan == .annual, let monthlyEquivalent = viewModel.formattedMonthlyEquivalent(for: plan) {
                    Text("\(monthlyEquivalent)/mo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(accentColor)
                } else {
                    Spacer().frame(height: 13)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentColor.opacity(0.1) : cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? accentColor : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            Task { await viewModel.purchase() }
        } label: {
            Text(viewModel.hasFreeTrial ? "Start Free Trial" : "Continue")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(viewModel.packagesLoaded ? accentColor : accentColor.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.packagesLoaded)
        .padding(.horizontal, 24)
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)

                Text("Processing...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
            )
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    CustomPaywallView(
        viewModel: PaywallViewModel(trigger: .onboarding, detectedSubscriptionCount: 12),
        onContinueFree: { print("Continue free") },
        onPurchaseSuccess: { print("Purchase success") }
    )
}
