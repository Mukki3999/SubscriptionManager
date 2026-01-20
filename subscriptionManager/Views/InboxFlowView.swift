//
//  InboxFlowView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

/// Container view that manages the scan → review → home flow
struct InboxFlowView: View {

    @StateObject private var viewModel = InboxViewModel()
    @StateObject private var accountViewModel = AccountConnectionViewModel()
    @Binding var showHome: Bool

    var body: some View {
        ZStack {
            switch viewModel.viewState {
            case .idle:
                // Start scanning automatically
                Color.black
                    .ignoresSafeArea()
                    .onAppear {
                        Task {
                            await viewModel.startScan(
                                hasGmailAccount: accountViewModel.gmailAccount != nil,
                                hasStoreKitAccess: accountViewModel.hasStoreKitAccess
                            )
                        }
                    }

            case .scanning:
                ScanningView(progress: viewModel.scanProgress)
                    .transition(.opacity)

            case .review:
                SubscriptionReviewView(
                    viewModel: viewModel,
                    onComplete: {
                        showHome = true
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
    }
}

// MARK: - Preview

#Preview {
    InboxFlowView(showHome: .constant(false))
}
