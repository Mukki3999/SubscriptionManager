//
//  OnboardingView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/15/26.
//

import SwiftUI
import AVKit
import UIKit

// MARK: - Looping Video Player
struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExtension: String

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(videoName: videoName, videoExtension: videoExtension)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class PlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?

    init(videoName: String, videoExtension: String) {
        super.init(frame: .zero)

        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            print("Video file not found: \(videoName).\(videoExtension)")
            return
        }

        let playerItem = AVPlayerItem(url: url)
        queuePlayer = AVQueuePlayer(playerItem: playerItem)
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        // Create looper
        if let player = queuePlayer {
            playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        }

        queuePlayer?.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - Figma Logo (from Asset Catalog)
struct FigmaLogo: View {
    var body: some View {
        Image("FigmaLogo")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - OpenAI Logo (from Asset Catalog)
struct OpenAILogo: View {
    var body: some View {
        Image("OpenAILogo")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Spotify Logo (from Asset Catalog)
struct SpotifyLogoAsset: View {
    var body: some View {
        Image("SpotifyLogo 1")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Claude Logo (from Asset Catalog)
struct ClaudeLogo: View {
    var body: some View {
        Image("claude-logo")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Apple Logo (from Asset Catalog)
struct AppleLogo: View {
    var body: some View {
        Image("AppleMusicLogo")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Logo Circle Container
struct LogoCircle<Content: View>: View {
    let size: CGFloat
    let content: Content
    let isCenter: Bool

    init(size: CGFloat, isCenter: Bool = false, @ViewBuilder content: () -> Content) {
        self.size = size
        self.isCenter = isCenter
        self.content = content()
    }

    var body: some View {
        ZStack {
            if isCenter {
                // Center logo (Spotify) - just the logo, no border
                content
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Outer logos - glassmorphic card circle with brighter background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                content
                    .frame(width: size * 0.55, height: size * 0.55)
                    .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Subscription Logos Row
struct SubscriptionLogosRow: View {
    let smallLogoSize: CGFloat = 64
    let mediumLogoSize: CGFloat = 82
    let largeLogoSize: CGFloat = 110
    let overlap: CGFloat = 20

    @State private var appeared = false
    @State private var glowPosition: CGFloat = -60

    var body: some View {
        ZStack {
            // Animated glow - sweeps left to right
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.8),
                            Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.5),
                            Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: glowPosition)
                .opacity(appeared ? 1 : 0)
                .blur(radius: 25)

            HStack(spacing: -overlap) {
                LogoCircle(size: smallLogoSize) {
                    FigmaLogo()
                }
                .offset(y: appeared ? 0 : 50)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)
                .zIndex(1)

                LogoCircle(size: mediumLogoSize) {
                    OpenAILogo()
                }
                .offset(y: appeared ? 0 : 50)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                .zIndex(2)

                LogoCircle(size: largeLogoSize, isCenter: true) {
                    SpotifyLogoAsset()
                }
                .offset(y: appeared ? 0 : 50)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
                .zIndex(5)

                LogoCircle(size: mediumLogoSize) {
                    ClaudeLogo()
                }
                .offset(y: appeared ? 0 : 50)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appeared)
                .zIndex(2)

                LogoCircle(size: smallLogoSize) {
                    AppleLogo()
                }
                .offset(y: appeared ? 0 : 50)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)
                .zIndex(1)
            }
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.5)) {
                glowPosition = 60
            }
        }
    }
}

// MARK: - Video Container with Rounded Corners
struct OnboardingVideoView: View {
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let videoWidth = geo.size.width * 0.72
            let visibleHeight = geo.size.height * 0.9
            // Make the video taller than visible area so we can crop the top
            let videoHeight = videoWidth * 2.0
            // Amount to shift video up to crop the black top space
            let cropOffset: CGFloat = videoHeight * 0.18

            ZStack {
                // Glow effect behind video
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.4),
                                Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 180
                        )
                    )
                    .frame(width: videoWidth + 40, height: visibleHeight + 40)
                    .blur(radius: 30)
                    .opacity(appeared ? 1 : 0)

                // Video player with cropping to hide top black space
                LoopingVideoPlayer(videoName: "onboarding_video", videoExtension: "mp4")
                    .frame(width: videoWidth, height: videoHeight)
                    .offset(y: -cropOffset)
                    .frame(width: videoWidth, height: visibleHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Page Indicator
struct PageIndicator: View {
    let totalPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
}

// MARK: - Notification Mockup
struct NotificationMockup: View {
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Subscription Renewal")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)

                    Spacer()

                    Text("Yesterday, 10:39 PM")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.45))
                }

                Text("Your OpenAI subscription ($20.00/mo) renews tomorrow.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.25))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.93, blue: 0.95),
                            Color(red: 0.88, green: 0.89, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Onboarding Page 1 - Logo Animation
struct OnboardingPage1: View {
    @State private var textAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            SubscriptionLogosRow()
                .padding(.bottom, 60)

            Text("Manage all your\nsubscriptions")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .offset(y: textAppeared ? 0 : 30)
                .opacity(textAppeared ? 1 : 0)

            Text("Keep regular expenses on hand\nand receive timely notifications of\nupcoming fees")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 20)
                .offset(y: textAppeared ? 0 : 30)
                .opacity(textAppeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                textAppeared = true
            }
        }
    }
}

// MARK: - Onboarding Page 2 - Video
struct OnboardingPage2: View {
    @State private var textAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 40)

            OnboardingVideoView()
                .frame(height: 400)
                .padding(.bottom, 30)

            Text("Track your spending\nat a glance")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .offset(y: textAppeared ? 0 : 30)
                .opacity(textAppeared ? 1 : 0)

            Text("See all your subscriptions in one place\nwith renewal dates and costs")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 20)
                .offset(y: textAppeared ? 0 : 30)
                .opacity(textAppeared ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                textAppeared = true
            }
        }
    }
}

// MARK: - Onboarding Page 3 - Notifications
struct OnboardingPage3: View {
    @State private var textAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            NotificationMockup()
                .padding(.bottom, 60)

            Text("Get real-time\nnotifications")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .offset(y: textAppeared ? 0 : 30)
                .opacity(textAppeared ? 1 : 0)

            Text("Never miss a renewal date with\ntimely reminders before you're charged")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 20)
                .offset(y: textAppeared ? 0 : 30)
                .opacity(textAppeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                textAppeared = true
            }
        }
    }
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    let onGetStarted: () -> Void

    @State private var currentPage = 0
    @State private var buttonAppeared = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.07, green: 0.07, blue: 0.08)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Paged content
                TabView(selection: $currentPage) {
                    OnboardingPage1()
                        .tag(0)

                    OnboardingPage2()
                        .tag(1)

                    OnboardingPage3()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom section with indicator and button
                VStack(spacing: 24) {
                    PageIndicator(totalPages: totalPages, currentPage: currentPage)

                    Button(action: {
                        if currentPage < totalPages - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            onGetStarted()
                        }
                    }) {
                        Text(currentPage == totalPages - 1 ? "Get started" : "Next")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.25, green: 0.52, blue: 0.96))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 50)
                .offset(y: buttonAppeared ? 0 : 30)
                .opacity(buttonAppeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
                buttonAppeared = true
            }
        }
    }
}

#Preview {
    OnboardingView(onGetStarted: {})
}
