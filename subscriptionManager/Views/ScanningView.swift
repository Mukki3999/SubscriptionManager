//
//  ScanningView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI

// MARK: - Brand Logo Views for Scanning

struct ScanSpotifyLogo: View {
    var body: some View {
        Image("SpotifyLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct ScanOpenAILogo: View {
    var body: some View {
        Image("OpenAILogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct ScanYouTubeLogo: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Red rounded rectangle
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color(red: 1.0, green: 0.0, blue: 0.0))
                    .frame(width: size * 0.85, height: size * 0.6)

                // White play triangle
                ScanPlayTriangle()
                    .fill(Color.white)
                    .frame(width: size * 0.25, height: size * 0.3)
                    .offset(x: size * 0.03)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width/2, y: geo.size.height/2)
        }
    }
}

struct ScanPlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height/2))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct ScanDiscordLogo: View {
    var body: some View {
        Image("DiscordLogo")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipShape(Circle())
    }
}

/// Animated scanning progress view
struct ScanningView: View {

    let progress: ScanProgress

    // Animation states
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var appeared = false
    @State private var logoRotation: Double = 0

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.05, green: 0.05, blue: 0.06)
                .ignoresSafeArea()

            // Subtle radial glow behind icons
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.11, green: 0.73, blue: 0.33).opacity(glowOpacity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(y: -100)
                .blur(radius: 40)

            VStack(spacing: 40) {
                Spacer()

                // Animated brand logo cluster
                animatedBrandCluster
                    .padding(.bottom, 20)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)

                // Status text
                VStack(spacing: 20) {
                    Text("Scanning...")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)

                    // Source-specific progress rows
                    VStack(spacing: 12) {
                        // Gmail progress row (only show if Gmail account connected)
                        if progress.hasGmailAccount {
                            scanSourceRow(
                                assetImage: "GmailLogo 1",
                                title: "Gmail",
                                status: progress.phase.rawValue,
                                detail: progress.emailsScanned > 0 ? "\(progress.emailsScanned) emails" : nil,
                                candidatesFound: progress.candidatesFound,
                                isComplete: progress.phase == .complete
                            )
                        }

                        // App Store progress row (only show if not unavailable)
                        if progress.storeKitPhase != .unavailable {
                            scanSourceRow(
                                icon: "apple.logo",
                                iconColor: .white,
                                title: "App Store",
                                status: progress.storeKitPhase.rawValue,
                                detail: progress.transactionsScanned > 0 ? "\(progress.transactionsScanned) transactions" : nil,
                                candidatesFound: progress.storeKitCandidatesFound,
                                isComplete: progress.storeKitPhase == .complete
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Total subscriptions found
                    let totalFound = progress.candidatesFound + progress.storeKitCandidatesFound
                    if totalFound > 0 {
                        Text("\(totalFound) subscriptions found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
            startAnimations()
        }
    }

    // MARK: - Animated Brand Logo Cluster

    private var animatedBrandCluster: some View {
        ZStack {
            // Subtle background circle (minimal pulse)
            Circle()
                .fill(Color.white.opacity(0.03))
                .frame(width: 260, height: 260)
                .scaleEffect(pulseScale)

            // Brand logo grid - rotates as a whole, logos stay upright
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    // Discord
                    brandLogoCircle(size: 82) {
                        ScanDiscordLogo()
                            .frame(width: 42, height: 42)
                    }

                    // YouTube
                    brandLogoCircle(size: 82) {
                        ScanYouTubeLogo()
                            .frame(width: 44, height: 44)
                    }
                }
                HStack(spacing: 20) {
                    // OpenAI
                    brandLogoCircle(size: 82) {
                        ScanOpenAILogo()
                            .frame(width: 42, height: 42)
                    }

                    // Spotify
                    brandLogoCircle(size: 82) {
                        ScanSpotifyLogo()
                            .frame(width: 45, height: 45)
                    }
                }
            }
            .rotationEffect(.degrees(logoRotation))
        }
    }

    private func brandLogoCircle<Content: View>(size: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            // Background circle - light gray like onboarding
            Circle()
                .fill(Color(red: 0.75, green: 0.77, blue: 0.78))
                .frame(width: size, height: size)

            // Counter-rotate the logo so it stays visually upright
            content()
                .rotationEffect(.degrees(-logoRotation))
        }
    }

    // MARK: - Scan Source Row

    private func scanSourceRow(
        icon: String? = nil,
        assetImage: String? = nil,
        iconColor: Color = .white,
        title: String,
        status: String,
        detail: String?,
        candidatesFound: Int,
        isComplete: Bool
    ) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 36, height: 36)

                if let assetImage = assetImage {
                    Image(assetImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
            }

            // Title and status
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                    }

                    if let detail = detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                    } else {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
            }

            Spacer()

            // Candidates found badge
            if candidatesFound > 0 {
                Text("\(candidatesFound)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.2))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Animations

    private func startAnimations() {
        isAnimating = true

        // Very subtle pulse animation for background circle
        withAnimation(
            Animation.easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.03
        }

        // Subtle glow pulse animation
        withAnimation(
            Animation.easeInOut(duration: 3.5)
                .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 0.4
        }

        // Continuous 360° rotation for logo containers
        withAnimation(
            Animation.linear(duration: 5.0)
                .repeatForever(autoreverses: false)
        ) {
            logoRotation = 360
        }
    }
}

// MARK: - Preview

#Preview {
    ScanningView(
        progress: ScanProgress(
            phase: .fetchingMetadata,
            emailsScanned: 127,
            candidatesFound: 5,
            hasGmailAccount: true,
            storeKitPhase: .fetchingTransactions,
            transactionsScanned: 12,
            storeKitCandidatesFound: 3
        )
    )
}
