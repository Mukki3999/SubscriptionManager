//
//  ContentView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import SwiftUI

/// App navigation state
enum AppScreen {
    case onboarding
    case accountConnection
    case inbox
    case home
}

struct ContentView: View {

    @State private var currentScreen: AppScreen
    @State private var showHome = false
    @State private var inboxManualEntry = false

    private let subscriptionsKey = "confirmedSubscriptions"
    private let accountsStorageKey = "connectedAccounts"

    init() {
        _currentScreen = State(initialValue: Self.determineInitialScreen(
            subscriptionsKey: "confirmedSubscriptions",
            accountsStorageKey: "connectedAccounts"
        ))
    }

    // MARK: - Account Deletion Handler

    private func handleAccountDeletion() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = .onboarding
            showHome = false
            inboxManualEntry = false
        }
    }

    var body: some View {
        ZStack {
            switch currentScreen {
            case .onboarding:
                OnboardingView(
                    onGetStarted: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentScreen = .accountConnection
                        }
                    }
                )
                .transition(.opacity)

            case .accountConnection:
                AccountConnectionView(
                    onContinue: {
                        inboxManualEntry = false
                        currentScreen = .inbox
                    },
                    onAddManually: {
                        inboxManualEntry = true
                        currentScreen = .inbox
                    }
                )
                .transition(.opacity)

            case .inbox:
                InboxFlowView(showHome: $showHome, isManualEntry: inboxManualEntry)
                    .transition(.move(edge: .trailing))
                    .onChange(of: showHome) { _, newValue in
                        if newValue {
                            withAnimation {
                                currentScreen = .home
                                inboxManualEntry = false
                            }
                        }
                    }

            case .home:
                HomeView()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentScreen)
        .onReceive(NotificationCenter.default.publisher(for: .accountDeleted)) { _ in
            handleAccountDeletion()
        }
    }

    // MARK: - Initial Screen Selection

    private static func determineInitialScreen(subscriptionsKey: String, accountsStorageKey: String) -> AppScreen {
        if hasSavedSubscriptions(subscriptionsKey: subscriptionsKey) {
            return .home
        }

        if hasConnectedAccounts(accountsStorageKey: accountsStorageKey) {
            return .inbox
        }

        return .onboarding
    }

    private static func hasSavedSubscriptions(subscriptionsKey: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey),
              let subscriptions = try? JSONDecoder().decode([Subscription].self, from: data) else {
            return false
        }
        return !subscriptions.isEmpty
    }

    private static func hasConnectedAccounts(accountsStorageKey: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: accountsStorageKey),
              let accounts = try? JSONDecoder().decode([ConnectedAccount].self, from: data) else {
            return false
        }
        return !accounts.isEmpty
    }
}

#Preview {
    ContentView()
}
