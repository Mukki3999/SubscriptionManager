//
//  InboxFlowView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

/// Container view that manages the scan → review → paywall → home flow
struct InboxFlowView: View {

    @StateObject private var viewModel = InboxViewModel()
    @StateObject private var accountViewModel = AccountConnectionViewModel()
    @Binding var showHome: Bool
    let isManualEntry: Bool

    @State private var showPaywall = false
    @State private var paywallDismissed = false

    // Number of subscriptions detected for paywall messaging
    private var detectedCount: Int {
        viewModel.subscriptions.count
    }

    // Check if paywall should be shown (more than 3 subscriptions detected and user hasn't seen paywall yet)
    private var shouldShowPaywall: Bool {
        detectedCount > 3 && !paywallDismissed && TierManager.shared.currentTier == .free
    }

    var body: some View {
        ZStack {
            switch viewModel.viewState {
            case .idle:
                // Start scanning automatically
                Color.black
                    .ignoresSafeArea()
                    .onAppear {
                        if isManualEntry {
                            viewModel.startManualEntry()
                            return
                        }
                        Task {
                            await viewModel.startScan(
                                hasGmailAccount: accountViewModel.gmailAccount != nil,
                                hasStoreKitAccess: accountViewModel.hasStoreKitAccess
                            )
                            // Mark free scan as used
                            TierManager.shared.markFreeScanUsed()
                        }
                    }

            case .scanning:
                ScanningView(progress: viewModel.scanProgress)
                    .transition(.opacity)

            case .review:
                SubscriptionReviewView(
                    viewModel: viewModel,
                    onComplete: {
                        // Check if we should show paywall before going home
                        if shouldShowPaywall {
                            showPaywall = true
                        } else {
                            showHome = true
                        }
                    }
                )
                .transition(.move(edge: .trailing))

            case .complete:
                // Transition to home
                Color.clear
                    .onAppear {
                        showHome = true
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.viewState)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                trigger: .onboarding,
                detectedSubscriptionCount: detectedCount,
                onContinueFree: {
                    paywallDismissed = true
                    showHome = true
                },
                onPurchaseSuccess: {
                    paywallDismissed = true
                    showHome = true
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    InboxFlowView(showHome: .constant(false), isManualEntry: false)
}
