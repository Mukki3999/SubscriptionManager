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

    @State private var currentScreen: AppScreen = .onboarding
    @State private var showHome = false

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
                        currentScreen = .inbox
                    }
                )
                .transition(.opacity)

            case .inbox:
                InboxFlowView(showHome: $showHome)
                    .transition(.move(edge: .trailing))
                    .onChange(of: showHome) { _, newValue in
                        if newValue {
                            withAnimation {
                                currentScreen = .home
                            }
                        }
                    }

            case .home:
                HomeView()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentScreen)
    }
}

#Preview {
    ContentView()
}
