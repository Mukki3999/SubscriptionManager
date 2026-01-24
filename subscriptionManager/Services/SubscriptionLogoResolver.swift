//
//  SubscriptionLogoResolver.swift
//  subscriptionManager
//
//  Created by Codex on 1/25/26.
//

import Foundation

@MainActor
enum SubscriptionLogoResolver {
    static func assetName(for subscription: Subscription) -> String? {
        if let company = CompanyLogoService.shared.company(withId: subscription.merchantId),
           let logoAsset = company.logoAssetName {
            return logoAsset
        }

        return assetName(for: subscription.name)
    }

    static func assetName(for name: String) -> String? {
        if let company = CompanyLogoService.shared.findCompany(for: name),
           let logoAsset = company.logoAssetName {
            return logoAsset
        }

        let logoMap: [String: String] = [
            // Streaming
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

            // Music
            "Spotify": "SpotifyLogo 1",
            "Apple Music": "AppleMusicLogo",
            "Tidal": "TidalLogo",
            "Pandora": "PandoraLogo",
            "Deezer": "DeezerLogo",
            "SoundCloud": "SoundCloudLogo",
            "Audible": "AudibleLogo",

            // Productivity
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

            // Cloud Storage
            "Dropbox": "DropboxLogo",
            "iCloud+": "iCloudLogo",
            "iCloud": "iCloudLogo",
            "Google One": "GoogleOneLogo",

            // VPN & Security
            "1Password": "1PasswordLogo",
            "NordVPN": "NordVPNLogo",
            "ExpressVPN": "ExpressVPNLogo",
            "Surfshark": "SurfsharkLogo",
            "Bitwarden": "BitwardenLogo",
            "Dashlane": "DashlaneLogo",
            "LastPass": "LastPassLogo",
            "Proton": "ProtonLogo",

            // Social
            "Discord Nitro": "DiscordLogo",
            "Discord": "DiscordLogo",
            "LinkedIn Premium": "LinkedInLogo",
            "LinkedIn": "LinkedInLogo",
            "X Premium": "XLogo",
            "Twitter Blue": "XLogo",
            "Twitch": "TwitchLogo",

            // Gaming
            "Xbox Game Pass": "XboxLogo",
            "Xbox": "XboxLogo",
            "PlayStation Plus": "PlayStationLogo",
            "PlayStation": "PlayStationLogo",
            "Nintendo Switch Online": "NintendoLogo",
            "Nintendo": "NintendoLogo",
            "EA Play": "EALogo",

            // Fitness
            "Strava": "StravaLogo",
            "Headspace": "HeadspaceLogo",
            "Calm": "CalmLogo",
            "Peloton": "PelotonLogo",
            "MyFitnessPal": "MyFitnessPalLogo",
            "Fitbit": "FitbitLogo",

            // Education
            "Duolingo Plus": "DuolingoLogo",
            "Duolingo": "DuolingoLogo",
            "MasterClass": "MasterClassLogo",
            "Skillshare": "SkillshareLogo",
            "Coursera": "CourseraLogo",

            // News & Media
            "The New York Times": "NYTimesLogo",
            "NYTimes": "NYTimesLogo",
            "Medium": "MediumLogo",
            "The Economist": "EconomistLogo",
            "Wall Street Journal": "WSJLogo",
            "WSJ": "WSJLogo",
            "Washington Post": "WashingtonPostLogo",
            "Substack": "SubstackLogo",

            // Food & Delivery
            "DoorDash DashPass": "DoorDashLogo",
            "DoorDash": "DoorDashLogo",
            "Uber One": "UberEatsLogo",
            "Uber Eats": "UberEatsLogo",
            "Grubhub": "GrubhubLogo",
            "Instacart": "InstacartLogo",

            // Shopping
            "Amazon": "AmazonLogo",
            "Costco": "CostcoLogo",
            "Walmart+": "WalmartLogo",
            "Walmart": "WalmartLogo",

            // AI & Tools
            "ChatGPT Plus": "OpenAILogo",
            "ChatGPT": "OpenAILogo",
            "OpenAI": "OpenAILogo",
            "Claude": "ClaudeLogo",
            "Anthropic": "ClaudeLogo",
            "Midjourney": "MidjourneyLogo",
            "Grammarly": "GrammarlyLogo",

            // Other
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
