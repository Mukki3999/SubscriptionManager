//
//  NotificationsView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import SwiftUI

// MARK: - Notifications View

struct NotificationsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NotificationViewModel

    // MARK: - Constants

    private let darkBackground = Color(red: 0.11, green: 0.11, blue: 0.12)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                darkBackground
                    .ignoresSafeArea()

                if viewModel.notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Notifications")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.notifications.isEmpty {
                        Menu {
                            Button(role: .destructive, action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.clearAllNotifications()
                                }
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(darkBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            viewModel.markAllAsRead()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)

                Image(systemName: "bell.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
            }

            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text("You'll see renewal reminders here\nwhen your subscriptions are due.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.notifications) { notification in
                    NotificationRowView(
                        notification: notification,
                        logoImage: logoImageForSubscription(notification.subscriptionName),
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.deleteNotification(notification)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logo Lookup

    private func logoImageForSubscription(_ name: String) -> String? {
        // Try to find company in the logo service by name
        if let company = CompanyLogoService.shared.findCompany(for: name),
           let logoAsset = company.logoAssetName {
            return logoAsset
        }

        // Comprehensive logo map
        let logoMap: [String: String] = [
            "Netflix": "NetflixLogo",
            "Disney+": "DisneyPlusLogo",
            "YouTube Premium": "YouTubeLogo 1",
            "YouTube": "YouTubeLogo 1",
            "Hulu": "HuluLogo",
            "Max": "MaxLogo",
            "HBO Max": "MaxLogo",
            "Amazon Prime": "AmazonPrimeLogo",
            "Apple TV": "AppleTVLogo",
            "Apple TV+": "AppleTVLogo",
            "Peacock": "PeacockLogo",
            "Paramount+": "ParamountPlusLogo",
            "Crunchyroll": "CrunchyrollLogo",
            "Spotify": "SpotifyLogo 1",
            "Apple Music": "AppleMusicLogo",
            "Tidal": "TidalLogo",
            "Pandora": "PandoraLogo",
            "Deezer": "DeezerLogo",
            "SoundCloud": "SoundCloudLogo",
            "Audible": "AudibleLogo",
            "Adobe Creative Cloud": "AdobeLogo",
            "Adobe": "AdobeLogo",
            "Figma": "FigmaLogo",
            "Notion": "NotionLogo",
            "Slack": "SlackLogo",
            "Canva": "CanvaLogo",
            "Microsoft 365": "Microsoft365Logo",
            "Google Workspace": "GoogleWorkspaceLogo",
            "Asana": "AsanaLogo",
            "Trello": "TrelloLogo",
            "Linear": "LinearLogo",
            "Todoist": "TodoistLogo",
            "Evernote": "EvernoteLogo",
            "Bear": "BearLogo",
            "Craft": "CraftLogo",
            "Superhuman": "SuperhumanLogo",
            "Dropbox": "DropboxLogo",
            "iCloud+": "iCloudLogo",
            "iCloud": "iCloudLogo",
            "Google One": "GoogleOneLogo",
            "1Password": "1PasswordLogo",
            "NordVPN": "NordVPNLogo",
            "ExpressVPN": "ExpressVPNLogo",
            "Surfshark": "SurfsharkLogo",
            "Bitwarden": "BitwardenLogo",
            "Dashlane": "DashlaneLogo",
            "LastPass": "LastPassLogo",
            "Proton": "ProtonLogo",
            "Discord Nitro": "DiscordLogo",
            "Discord": "DiscordLogo",
            "LinkedIn Premium": "LinkedInLogo",
            "LinkedIn": "LinkedInLogo",
            "X Premium": "XLogo",
            "Twitter Blue": "XLogo",
            "Twitch": "TwitchLogo",
            "Xbox Game Pass": "XboxLogo",
            "Xbox": "XboxLogo",
            "PlayStation Plus": "PlayStationLogo",
            "PlayStation": "PlayStationLogo",
            "Nintendo Switch Online": "NintendoLogo",
            "Nintendo": "NintendoLogo",
            "EA Play": "EALogo",
            "Strava": "StravaLogo",
            "Headspace": "HeadspaceLogo",
            "Calm": "CalmLogo",
            "Peloton": "PelotonLogo",
            "MyFitnessPal": "MyFitnessPalLogo",
            "Fitbit": "FitbitLogo",
            "Duolingo Plus": "DuolingoLogo",
            "Duolingo": "DuolingoLogo",
            "MasterClass": "MasterClassLogo",
            "Skillshare": "SkillshareLogo",
            "Coursera": "CourseraLogo",
            "The New York Times": "NYTimesLogo",
            "NYTimes": "NYTimesLogo",
            "Medium": "MediumLogo",
            "The Economist": "EconomistLogo",
            "Wall Street Journal": "WSJLogo",
            "WSJ": "WSJLogo",
            "Washington Post": "WashingtonPostLogo",
            "Substack": "SubstackLogo",
            "DoorDash DashPass": "DoorDashLogo",
            "DoorDash": "DoorDashLogo",
            "Uber One": "UberEatsLogo",
            "Uber Eats": "UberEatsLogo",
            "Grubhub": "GrubhubLogo",
            "Instacart": "InstacartLogo",
            "Amazon": "AmazonLogo",
            "Costco": "CostcoLogo",
            "Walmart+": "WalmartLogo",
            "Walmart": "WalmartLogo",
            "ChatGPT Plus": "OpenAILogo",
            "ChatGPT": "OpenAILogo",
            "OpenAI": "OpenAILogo",
            "Claude": "ClaudeLogo",
            "Anthropic": "ClaudeLogo",
            "Midjourney": "MidjourneyLogo",
            "Grammarly": "GrammarlyLogo",
            "Zoom": "ZoomLogo",
            "GitHub": "GitHubLogo",
            "GitLab": "GitLabLogo",
            "Setapp": "SetappLogo",
            "CleanMyMac": "CleanMyMacLogo",
            "Parallels": "ParallelsLogo",
            "Raycast": "RaycastLogo",
            "Arc": "ArcLogo",
            "Sketch": "SketchLogo",
            "Procreate": "ProcreateLogo",
            "Affinity": "AffinityLogo",
            "Apple One": "AppleOneLogo",
            "Kindle Unlimited": "KindleLogo"
        ]
        return logoMap[name]
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {

    let notification: AppNotification
    let logoImage: String?
    let onDelete: () -> Void

    // MARK: - Constants

    private let cardBackground = Color(red: 0.16, green: 0.16, blue: 0.18)
    private let logoSize: CGFloat = 52
    private let logoCornerRadius: CGFloat = 14

    // MARK: - Body

    var body: some View {
        HStack(spacing: 14) {
            // Company Logo
            serviceLogo

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.subscriptionName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(renewalText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(urgencyColor)
                    }

                    Spacer()

                    // Price badge
                    Text(notification.formattedPrice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(urgencyColor.opacity(0.2))
                        )
                }

                // Time ago
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))

                    Text(timeAgoText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))

                    Spacer()

                    // Unread indicator
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(urgencyColor.opacity(0.15), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Service Logo

    private var serviceLogo: some View {
        Group {
            if let logoImage = logoImage, !logoImage.isEmpty {
                Image(logoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: logoCornerRadius, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: logoCornerRadius, style: .continuous)
                        .fill(urgencyColor.opacity(0.2))

                    Text(String(notification.subscriptionName.prefix(1)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(urgencyColor)
                }
                .frame(width: logoSize, height: logoSize)
            }
        }
    }

    // MARK: - Computed Properties

    private var urgencyColor: Color {
        let days = notification.daysUntilRenewal
        switch days {
        case ...0:
            return Color(red: 1.0, green: 0.35, blue: 0.35) // Soft red
        case 1:
            return Color(red: 1.0, green: 0.6, blue: 0.2)   // Soft orange
        default:
            return Color(red: 0.35, green: 0.75, blue: 1.0) // Soft blue
        }
    }

    private var renewalText: String {
        let days = notification.daysUntilRenewal
        switch days {
        case ...(-1):
            return "Renewed"
        case 0:
            return "Renews today"
        case 1:
            return "Renews tomorrow"
        default:
            return "Renews in \(days) days"
        }
    }

    private var timeAgoText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.createdAt, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    NotificationsView(viewModel: NotificationViewModel())
}
