//
//  AccountConnectionView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/12/26.
//

import SwiftUI

// MARK: - Gmail Logo (Custom SwiftUI)
struct GmailLogoView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // White background
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(Color.white)
                .frame(width: size, height: size * 0.75)

            // Gmail M shape
            GmailMShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.26, blue: 0.21), // Red
                            Color(red: 0.92, green: 0.26, blue: 0.21)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.7, height: size * 0.45)
        }
        .frame(width: size, height: size)
    }
}

struct GmailMShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // M shape for Gmail
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.6))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        return path
    }
}

// MARK: - Premium Account Connection View
struct AccountConnectionView: View {

    @StateObject private var viewModel = AccountConnectionViewModel()
    let onContinue: () -> Void
    let onAddManually: () -> Void

    @State private var appeared = false
    @State private var buttonsAppeared = false
    @State private var didRequestNotifications = false

    init(onContinue: @escaping () -> Void = {}, onAddManually: @escaping () -> Void = {}) {
        self.onContinue = onContinue
        self.onAddManually = onAddManually
    }

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.09),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle glow at top
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -250)
                .blur(radius: 60)

            VStack(spacing: 0) {
                // Title at top
                titleSection
                    .padding(.top, 80)
                    .padding(.horizontal, 24)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)

                if viewModel.hasConnectedAccounts {
                    connectedAccountsSection
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                }

                Spacer()

                // Connection buttons at bottom
                connectionButtonsSection
                    .padding(.horizontal, 24)
                    .offset(y: buttonsAppeared ? 0 : 40)
                    .opacity(buttonsAppeared ? 1 : 0)

                // Continue to Inbox Button
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                    .offset(y: buttonsAppeared ? 0 : 30)
                    .opacity(buttonsAppeared ? 1 : 0)
            }
        }
        .onAppear {
            requestNotificationPermissionIfNeeded()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                buttonsAppeared = true
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .overlay {
            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }
    
    private func requestNotificationPermissionIfNeeded() {
        guard !didRequestNotifications else { return }
        didRequestNotifications = true
        Task {
            let status = await NotificationService.shared.checkPermissionStatus()
            guard status == .notDetermined else { return }
            _ = await NotificationService.shared.requestPermission()
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Connect your")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 10) {
                Text("accounts")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color(red: 0.45, green: 0.55, blue: 0.95))
            }
        }
    }

    // MARK: - Connected Accounts Section
    private var connectedAccountsSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.connectedAccounts) { account in
                connectedAccountRow(account)
            }

            Text("You can remove accounts anytime in Settings.")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.5))
                .padding(.top, 8)
        }
    }

    private func connectedAccountRow(_ account: ConnectedAccount) -> some View {
        HStack(spacing: 14) {
            providerIcon(for: account.provider)

            Text(account.email)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Connection Buttons Section
    private var connectionButtonsSection: some View {
        VStack(spacing: 14) {
            // Gmail Button
            connectionButton(
                provider: .gmail,
                title: viewModel.gmailAccount != nil ? "Gmail Connected" : "Continue with Gmail",
                subtitle: nil,
                isConnected: viewModel.gmailAccount != nil,
                action: {
                    Task {
                        await viewModel.connectGmail()
                    }
                }
            )

            // Apple Button
            connectionButton(
                provider: .apple,
                title: viewModel.appleAccount != nil ? "Apple Connected" : "Continue with Apple",
                subtitle: viewModel.hasStoreKitAccess ? "App Store purchases enabled" : nil,
                isConnected: viewModel.appleAccount != nil,
                action: {
                    Task {
                        await viewModel.connectApple()
                    }
                }
            )
        }
    }

    private func connectionButton(provider: EmailProvider, title: String, subtitle: String?, isConnected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                providerIcon(for: provider)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                    }
                }

                Spacer()

                if isConnected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PremiumButtonStyle())
    }

    // MARK: - Provider Icon
    private func providerIcon(for provider: EmailProvider) -> some View {
        ZStack {
            if provider == .gmail {
                // Gmail asset in same circular style as Apple
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image("gmail")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                    )
            } else {
                // Apple icon
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "applelogo")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                    )
            }
        }
    }

    // MARK: - Continue Button
    private var continueButton: some View {
        Button(action: {
            if viewModel.hasConnectedAccounts {
                onContinue()
            } else {
                onAddManually()
            }
        }) {
            Text(viewModel.hasConnectedAccounts ? "Continue to Inbox" : "Add Subscriptions Manually")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(viewModel.hasConnectedAccounts ? Color(red: 0.25, green: 0.52, blue: 0.96) : Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(viewModel.hasConnectedAccounts ? 0 : 0.12), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PremiumButtonStyle())
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)

                Text("Connecting...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(white: 0.7))
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Gmail Icon View (Colorful M)
struct GmailIconView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Envelope base
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: 1.5)

                // M shape with gradient colors
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 2))
                    path.addLine(to: CGPoint(x: w/2, y: h * 0.65))
                    path.addLine(to: CGPoint(x: w, y: 2))
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.26, blue: 0.21), // Red
                            Color(red: 0.23, green: 0.52, blue: 0.95)  // Blue
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

// MARK: - Premium Button Style
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    AccountConnectionView()
}
