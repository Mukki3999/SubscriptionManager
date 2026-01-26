//
//  SettingsView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/25/26.
//

import PhotosUI
import SwiftUI

/// Settings view for managing profile, connected accounts, and app preferences
struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Bindings

    @Binding var profileImageData: Data?

    // MARK: - State

    @StateObject private var accountViewModel = AccountConnectionViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDisconnectGmailAlert = false
    @State private var showDisconnectAppleAlert = false
    @State private var showPaywall = false

    // MARK: - Constants

    private let profileImageKey = "userProfile.imageData"
    private let termsURL = "https://sparkly-flat-825.notion.site/Terms-of-Service-Trackit-2f3c24ebe50e80b8a67acfe3310d31d4"
    private let privacyURL = "https://sparkly-flat-825.notion.site/Privacy-Policy-Trackit-2f3c24ebe50e8033b1fae997507127cd?pvs=74"

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.06)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile Section
                        profileSection

                        // Connected Accounts Section
                        connectedAccountsSection

                        // Subscription Section
                        subscriptionSection

                        // About Section
                        aboutSection

                        // App Version
                        appVersionText
                            .padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(Color(red: 0.05, green: 0.05, blue: 0.06), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                        await MainActor.run {
                            profileImageData = jpegData
                            UserDefaults.standard.set(jpegData, forKey: profileImageKey)
                        }
                    }
                }
            }
            .alert("Disconnect Gmail", isPresented: $showDisconnectGmailAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task {
                        await accountViewModel.disconnectGmail()
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect your Gmail account? You'll need to reconnect to scan emails.")
            }
            .alert("Disconnect Apple", isPresented: $showDisconnectAppleAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    if let account = accountViewModel.appleAccount {
                        accountViewModel.removeAccount(account)
                    }
                }
            } message: {
                Text("Are you sure you want to disconnect your Apple account? You'll need to reconnect to scan App Store purchases.")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView(
                    trigger: .featureGate("Settings Upgrade"),
                    onPurchaseSuccess: {
                        showPaywall = false
                    }
                )
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Profile Photo")

            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 16) {
                    // Profile Image
                    ZStack {
                        if let profileImageData,
                           let uiImage = UIImage(data: profileImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Change Photo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Text("Tap to select from gallery")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Connected Accounts Section

    private var connectedAccountsSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Connected Accounts")

            VStack(spacing: 0) {
                // Gmail Account Row
                accountRow(
                    icon: "GmailLogo 1",
                    isAssetImage: true,
                    title: "Gmail",
                    subtitle: accountViewModel.gmailAccount?.email,
                    isConnected: accountViewModel.gmailAccount != nil,
                    onDisconnect: { showDisconnectGmailAlert = true }
                )

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)

                // Apple Account Row
                accountRow(
                    icon: "apple.logo",
                    isAssetImage: false,
                    title: "Apple",
                    subtitle: accountViewModel.appleAccount != nil ? "App Store Access" : nil,
                    isConnected: accountViewModel.appleAccount != nil,
                    onDisconnect: { showDisconnectAppleAlert = true }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private func accountRow(
        icon: String,
        isAssetImage: Bool,
        title: String,
        subtitle: String?,
        isConnected: Bool,
        onDisconnect: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)

                if isAssetImage {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                } else {
                    Text("Not connected")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            if isConnected {
                Button(action: onDisconnect) {
                    Text("Disconnect")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(16)
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(spacing: 16) {
            sectionHeader("Subscription")

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(currentTierColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: currentTierIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(currentTierColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentTierName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(currentTierDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                if TierManager.shared.currentTier == .free {
                    Button(action: { showPaywall = true }) {
                        Text("Upgrade")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: openSubscriptionManagement) {
                        Text("Manage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private var currentTierName: String {
        switch TierManager.shared.currentTier {
        case .free: return "Free Plan"
        case .pro: return "Pro Plan"
        }
    }

    private var currentTierDescription: String {
        switch TierManager.shared.currentTier {
        case .free: return "Limited features"
        case .pro: return "All features unlocked"
        }
    }

    private var currentTierIcon: String {
        switch TierManager.shared.currentTier {
        case .free: return "person.fill"
        case .pro: return "crown.fill"
        }
    }

    private var currentTierColor: Color {
        switch TierManager.shared.currentTier {
        case .free: return .gray
        case .pro: return Color(red: 0.2, green: 0.78, blue: 0.35)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 16) {
            sectionHeader("About")

            VStack(spacing: 0) {
                // Terms of Service
                linkRow(
                    icon: "doc.text",
                    title: "Terms of Service",
                    url: termsURL
                )

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.horizontal, 16)

                // Privacy Policy
                linkRow(
                    icon: "hand.raised",
                    title: "Privacy Policy",
                    url: privacyURL
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private func linkRow(icon: String, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
        }
    }

    // MARK: - App Version

    private var appVersionText: some View {
        VStack(spacing: 4) {
            Text("Trackit - Subscription Manager")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Text("Version \(appVersion)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()
        }
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(profileImageData: .constant(nil))
}
