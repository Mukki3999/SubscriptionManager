//
//  MerchantDatabase.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import Foundation
import SwiftUI

// MARK: - Merchant Info

struct MerchantInfo {
    let id: String
    let name: String
    let domains: [String]
    let senderPatterns: [String]
    let iconName: String
    let iconColor: Color
    let category: MerchantCategory
    let typicalPrices: [Double]?
    let typicalCycle: BillingCycle

    /// Base confidence boost for known merchants
    var confidenceBoost: Int { 25 }
}

// MARK: - Merchant Category

enum MerchantCategory: String {
    case streaming = "Streaming"
    case music = "Music"
    case productivity = "Productivity"
    case cloud = "Cloud Storage"
    case gaming = "Gaming"
    case fitness = "Fitness"
    case news = "News & Media"
    case software = "Software"
    case finance = "Finance"
    case food = "Food & Delivery"
    case shopping = "Shopping"
    case education = "Education"
    case utilities = "Utilities"
    case other = "Other"
}

// MARK: - Merchant Database

final class MerchantDatabase {

    static let shared = MerchantDatabase()

    private init() {}

    // MARK: - Known Merchants

    let merchants: [MerchantInfo] = [
        // Streaming
        MerchantInfo(
            id: "netflix",
            name: "Netflix",
            domains: ["netflix.com"],
            senderPatterns: ["netflix", "nflx"],
            iconName: "play.rectangle.fill",
            iconColor: Color(red: 229/255, green: 9/255, blue: 20/255),
            category: MerchantCategory.streaming,
            typicalPrices: [6.99, 15.49, 22.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "hulu",
            name: "Hulu",
            domains: ["hulu.com", "hulumail.com"],
            senderPatterns: ["hulu"],
            iconName: "play.rectangle.fill",
            iconColor: Color(red: 28/255, green: 231/255, blue: 131/255),
            category: MerchantCategory.streaming,
            typicalPrices: [7.99, 17.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "disney_plus",
            name: "Disney+",
            domains: ["disneyplus.com", "disney.com"],
            senderPatterns: ["disney+", "disneyplus", "disney plus"],
            iconName: "play.rectangle.fill",
            iconColor: Color(red: 17/255, green: 60/255, blue: 207/255),
            category: MerchantCategory.streaming,
            typicalPrices: [7.99, 13.99, 139.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "hbo_max",
            name: "Max",
            domains: ["hbomax.com", "max.com"],
            senderPatterns: ["hbo", "max"],
            iconName: "play.rectangle.fill",
            iconColor: Color(red: 89/255, green: 49/255, blue: 150/255),
            category: MerchantCategory.streaming,
            typicalPrices: [9.99, 15.99, 19.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "amazon_prime",
            name: "Amazon Prime",
            domains: ["amazon.com"],
            senderPatterns: ["amazon prime", "prime video", "prime membership"],
            iconName: "shippingbox.fill",
            iconColor: Color(red: 255/255, green: 153/255, blue: 0/255),
            category: MerchantCategory.streaming,
            typicalPrices: [14.99, 139.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "paramount_plus",
            name: "Paramount+",
            domains: ["paramountplus.com", "paramount.com"],
            senderPatterns: ["paramount"],
            iconName: "play.rectangle.fill",
            iconColor: Color(red: 0/255, green: 100/255, blue: 210/255),
            category: MerchantCategory.streaming,
            typicalPrices: [5.99, 11.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "peacock",
            name: "Peacock",
            domains: ["peacocktv.com"],
            senderPatterns: ["peacock"],
            iconName: "play.rectangle.fill",
            iconColor: Color(red: 0/255, green: 0/255, blue: 0/255),
            category: MerchantCategory.streaming,
            typicalPrices: [5.99, 11.99],
            typicalCycle: BillingCycle.monthly
        ),

        // Music
        MerchantInfo(
            id: "spotify",
            name: "Spotify",
            domains: ["spotify.com"],
            senderPatterns: ["spotify"],
            iconName: "waveform",
            iconColor: Color(red: 30/255, green: 215/255, blue: 96/255),
            category: MerchantCategory.music,
            typicalPrices: [10.99, 16.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "apple_music",
            name: "Apple Music",
            domains: ["apple.com", "itunes.com"],
            senderPatterns: ["apple music"],
            iconName: "music.note",
            iconColor: Color(red: 252/255, green: 60/255, blue: 68/255),
            category: MerchantCategory.music,
            typicalPrices: [10.99, 16.99, 109.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "youtube_music",
            name: "YouTube Music",
            domains: ["youtube.com", "google.com"],
            senderPatterns: ["youtube music", "youtube premium"],
            iconName: "music.note",
            iconColor: Color(red: 255/255, green: 0/255, blue: 0/255),
            category: MerchantCategory.music,
            typicalPrices: [10.99, 13.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "tidal",
            name: "TIDAL",
            domains: ["tidal.com"],
            senderPatterns: ["tidal"],
            iconName: "waveform",
            iconColor: Color.black,
            category: MerchantCategory.music,
            typicalPrices: [10.99, 19.99],
            typicalCycle: BillingCycle.monthly
        ),

        // Cloud & Productivity
        MerchantInfo(
            id: "icloud",
            name: "iCloud+",
            domains: ["apple.com"],
            senderPatterns: ["icloud", "icloud+", "icloud storage"],
            iconName: "icloud.fill",
            iconColor: Color(red: 52/255, green: 170/255, blue: 220/255),
            category: MerchantCategory.cloud,
            typicalPrices: [0.99, 2.99, 9.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "google_one",
            name: "Google One",
            domains: ["google.com"],
            senderPatterns: ["google one", "google storage"],
            iconName: "cloud.fill",
            iconColor: Color(red: 66/255, green: 133/255, blue: 244/255),
            category: MerchantCategory.cloud,
            typicalPrices: [1.99, 2.99, 9.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "dropbox",
            name: "Dropbox",
            domains: ["dropbox.com", "dropboxmail.com"],
            senderPatterns: ["dropbox"],
            iconName: "shippingbox.fill",
            iconColor: Color(red: 0/255, green: 97/255, blue: 255/255),
            category: MerchantCategory.cloud,
            typicalPrices: [11.99, 19.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "microsoft_365",
            name: "Microsoft 365",
            domains: ["microsoft.com", "office.com"],
            senderPatterns: ["microsoft 365", "office 365", "microsoft subscription"],
            iconName: "square.grid.2x2.fill",
            iconColor: Color(red: 0/255, green: 120/255, blue: 212/255),
            category: MerchantCategory.productivity,
            typicalPrices: [6.99, 9.99, 99.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "adobe_cc",
            name: "Adobe Creative Cloud",
            domains: ["adobe.com"],
            senderPatterns: ["adobe", "creative cloud"],
            iconName: "paintbrush.fill",
            iconColor: Color(red: 255/255, green: 0/255, blue: 0/255),
            category: MerchantCategory.software,
            typicalPrices: [9.99, 22.99, 54.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "notion",
            name: "Notion",
            domains: ["notion.so", "makenotion.com"],
            senderPatterns: ["notion"],
            iconName: "doc.text.fill",
            iconColor: Color.black,
            category: MerchantCategory.productivity,
            typicalPrices: [8.00, 10.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "slack",
            name: "Slack",
            domains: ["slack.com"],
            senderPatterns: ["slack"],
            iconName: "number",
            iconColor: Color(red: 74/255, green: 21/255, blue: 75/255),
            category: MerchantCategory.productivity,
            typicalPrices: [7.25, 12.50],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "figma",
            name: "Figma",
            domains: ["figma.com"],
            senderPatterns: ["figma"],
            iconName: "pencil.and.ruler.fill",
            iconColor: Color(red: 162/255, green: 89/255, blue: 255/255),
            category: MerchantCategory.software,
            typicalPrices: [12.00, 15.00],
            typicalCycle: BillingCycle.monthly
        ),

        // Gaming
        MerchantInfo(
            id: "xbox_gamepass",
            name: "Xbox Game Pass",
            domains: ["microsoft.com", "xbox.com"],
            senderPatterns: ["xbox", "game pass", "gamepass"],
            iconName: "gamecontroller.fill",
            iconColor: Color(red: 16/255, green: 124/255, blue: 16/255),
            category: MerchantCategory.gaming,
            typicalPrices: [9.99, 14.99, 16.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "playstation_plus",
            name: "PlayStation Plus",
            domains: ["playstation.com", "sony.com"],
            senderPatterns: ["playstation", "ps plus", "psn"],
            iconName: "gamecontroller.fill",
            iconColor: Color(red: 0/255, green: 55/255, blue: 145/255),
            category: MerchantCategory.gaming,
            typicalPrices: [9.99, 14.99, 17.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "nintendo_online",
            name: "Nintendo Switch Online",
            domains: ["nintendo.com"],
            senderPatterns: ["nintendo", "switch online"],
            iconName: "gamecontroller.fill",
            iconColor: Color(red: 230/255, green: 0/255, blue: 18/255),
            category: MerchantCategory.gaming,
            typicalPrices: [3.99, 7.99, 49.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "apple_arcade",
            name: "Apple Arcade",
            domains: ["apple.com"],
            senderPatterns: ["apple arcade"],
            iconName: "gamecontroller.fill",
            iconColor: Color(red: 0/255, green: 122/255, blue: 255/255),
            category: MerchantCategory.gaming,
            typicalPrices: [6.99],
            typicalCycle: BillingCycle.monthly
        ),

        // Fitness
        MerchantInfo(
            id: "apple_fitness",
            name: "Apple Fitness+",
            domains: ["apple.com"],
            senderPatterns: ["apple fitness", "fitness+"],
            iconName: "figure.run",
            iconColor: Color(red: 173/255, green: 255/255, blue: 47/255),
            category: MerchantCategory.fitness,
            typicalPrices: [9.99, 79.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "peloton",
            name: "Peloton",
            domains: ["onepeloton.com", "peloton.com"],
            senderPatterns: ["peloton"],
            iconName: "figure.indoor.cycle",
            iconColor: Color(red: 223/255, green: 38/255, blue: 38/255),
            category: MerchantCategory.fitness,
            typicalPrices: [12.99, 44.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "strava",
            name: "Strava",
            domains: ["strava.com"],
            senderPatterns: ["strava"],
            iconName: "figure.run",
            iconColor: Color(red: 252/255, green: 76/255, blue: 2/255),
            category: MerchantCategory.fitness,
            typicalPrices: [11.99, 79.99],
            typicalCycle: BillingCycle.monthly
        ),

        // News & Media
        MerchantInfo(
            id: "nytimes",
            name: "New York Times",
            domains: ["nytimes.com"],
            senderPatterns: ["new york times", "nytimes", "nyt"],
            iconName: "newspaper.fill",
            iconColor: Color.black,
            category: MerchantCategory.news,
            typicalPrices: [4.00, 17.00, 25.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "apple_news",
            name: "Apple News+",
            domains: ["apple.com"],
            senderPatterns: ["apple news"],
            iconName: "newspaper.fill",
            iconColor: Color(red: 250/255, green: 45/255, blue: 72/255),
            category: MerchantCategory.news,
            typicalPrices: [12.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "medium",
            name: "Medium",
            domains: ["medium.com"],
            senderPatterns: ["medium"],
            iconName: "text.alignleft",
            iconColor: Color.black,
            category: MerchantCategory.news,
            typicalPrices: [5.00, 50.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "wsj",
            name: "Wall Street Journal",
            domains: ["wsj.com", "dowjones.com"],
            senderPatterns: ["wall street journal", "wsj"],
            iconName: "newspaper.fill",
            iconColor: Color.black,
            category: MerchantCategory.news,
            typicalPrices: [4.00, 38.99],
            typicalCycle: BillingCycle.monthly
        ),

        // Software & Dev Tools
        MerchantInfo(
            id: "github",
            name: "GitHub",
            domains: ["github.com"],
            senderPatterns: ["github"],
            iconName: "chevron.left.forwardslash.chevron.right",
            iconColor: Color.black,
            category: MerchantCategory.software,
            typicalPrices: [4.00, 21.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "openai",
            name: "ChatGPT Plus",
            domains: ["openai.com"],
            senderPatterns: ["openai", "chatgpt"],
            iconName: "sparkles",
            iconColor: Color(red: 16/255, green: 163/255, blue: 127/255),
            category: MerchantCategory.software,
            typicalPrices: [20.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "anthropic",
            name: "Claude Pro",
            domains: ["anthropic.com", "claude.ai"],
            senderPatterns: ["anthropic", "claude"],
            iconName: "sparkles",
            iconColor: Color(red: 204/255, green: 117/255, blue: 79/255),
            category: MerchantCategory.software,
            typicalPrices: [20.00],
            typicalCycle: BillingCycle.monthly
        ),

        // VPN & Security
        MerchantInfo(
            id: "nordvpn",
            name: "NordVPN",
            domains: ["nordvpn.com", "nordaccount.com"],
            senderPatterns: ["nordvpn", "nord"],
            iconName: "lock.shield.fill",
            iconColor: Color(red: 68/255, green: 114/255, blue: 196/255),
            category: MerchantCategory.software,
            typicalPrices: [3.99, 4.99, 12.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "expressvpn",
            name: "ExpressVPN",
            domains: ["expressvpn.com"],
            senderPatterns: ["expressvpn"],
            iconName: "lock.shield.fill",
            iconColor: Color(red: 218/255, green: 57/255, blue: 64/255),
            category: MerchantCategory.software,
            typicalPrices: [6.67, 9.99, 12.95],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "1password",
            name: "1Password",
            domains: ["1password.com"],
            senderPatterns: ["1password"],
            iconName: "key.fill",
            iconColor: Color(red: 25/255, green: 99/255, blue: 246/255),
            category: MerchantCategory.software,
            typicalPrices: [2.99, 4.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "lastpass",
            name: "LastPass",
            domains: ["lastpass.com"],
            senderPatterns: ["lastpass"],
            iconName: "key.fill",
            iconColor: Color(red: 211/255, green: 33/255, blue: 45/255),
            category: MerchantCategory.software,
            typicalPrices: [3.00, 4.00],
            typicalCycle: BillingCycle.monthly
        ),

        // Education
        MerchantInfo(
            id: "duolingo",
            name: "Duolingo Plus",
            domains: ["duolingo.com"],
            senderPatterns: ["duolingo"],
            iconName: "text.book.closed.fill",
            iconColor: Color(red: 88/255, green: 204/255, blue: 2/255),
            category: MerchantCategory.education,
            typicalPrices: [6.99, 12.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "skillshare",
            name: "Skillshare",
            domains: ["skillshare.com"],
            senderPatterns: ["skillshare"],
            iconName: "graduationcap.fill",
            iconColor: Color(red: 0/255, green: 255/255, blue: 132/255),
            category: MerchantCategory.education,
            typicalPrices: [13.99, 32.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "masterclass",
            name: "MasterClass",
            domains: ["masterclass.com"],
            senderPatterns: ["masterclass"],
            iconName: "play.circle.fill",
            iconColor: Color.black,
            category: MerchantCategory.education,
            typicalPrices: [10.00, 15.00, 20.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "coursera",
            name: "Coursera Plus",
            domains: ["coursera.org"],
            senderPatterns: ["coursera"],
            iconName: "graduationcap.fill",
            iconColor: Color(red: 0/255, green: 86/255, blue: 210/255),
            category: MerchantCategory.education,
            typicalPrices: [49.00, 59.00],
            typicalCycle: BillingCycle.monthly
        ),

        // Dating
        MerchantInfo(
            id: "tinder",
            name: "Tinder",
            domains: ["gotinder.com", "tinder.com"],
            senderPatterns: ["tinder"],
            iconName: "flame.fill",
            iconColor: Color(red: 254/255, green: 81/255, blue: 94/255),
            category: MerchantCategory.other,
            typicalPrices: [9.99, 19.99, 29.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "bumble",
            name: "Bumble",
            domains: ["bumble.com"],
            senderPatterns: ["bumble"],
            iconName: "heart.fill",
            iconColor: Color(red: 252/255, green: 207/255, blue: 6/255),
            category: MerchantCategory.other,
            typicalPrices: [16.99, 32.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "hinge",
            name: "Hinge",
            domains: ["hinge.co"],
            senderPatterns: ["hinge"],
            iconName: "heart.fill",
            iconColor: Color(red: 110/255, green: 89/255, blue: 89/255),
            category: MerchantCategory.other,
            typicalPrices: [29.99, 49.99],
            typicalCycle: BillingCycle.monthly
        ),

        // Food Delivery
        MerchantInfo(
            id: "doordash",
            name: "DoorDash DashPass",
            domains: ["doordash.com"],
            senderPatterns: ["doordash", "dashpass"],
            iconName: "bag.fill",
            iconColor: Color(red: 255/255, green: 49/255, blue: 56/255),
            category: MerchantCategory.food,
            typicalPrices: [9.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "ubereats",
            name: "Uber One",
            domains: ["uber.com"],
            senderPatterns: ["uber one", "uber eats pass"],
            iconName: "car.fill",
            iconColor: Color.black,
            category: MerchantCategory.food,
            typicalPrices: [9.99],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "grubhub",
            name: "Grubhub+",
            domains: ["grubhub.com"],
            senderPatterns: ["grubhub"],
            iconName: "bag.fill",
            iconColor: Color(red: 248/255, green: 99/255, blue: 52/255),
            category: MerchantCategory.food,
            typicalPrices: [9.99],
            typicalCycle: BillingCycle.monthly
        ),

        // Shopping
        MerchantInfo(
            id: "costco",
            name: "Costco Membership",
            domains: ["costco.com"],
            senderPatterns: ["costco"],
            iconName: "cart.fill",
            iconColor: Color(red: 0/255, green: 83/255, blue: 159/255),
            category: MerchantCategory.shopping,
            typicalPrices: [60.00, 120.00],
            typicalCycle: BillingCycle.yearly
        ),
        MerchantInfo(
            id: "walmart_plus",
            name: "Walmart+",
            domains: ["walmart.com"],
            senderPatterns: ["walmart+", "walmart plus"],
            iconName: "cart.fill",
            iconColor: Color(red: 0/255, green: 113/255, blue: 206/255),
            category: MerchantCategory.shopping,
            typicalPrices: [12.95, 98.00],
            typicalCycle: BillingCycle.monthly
        ),
        MerchantInfo(
            id: "instacart",
            name: "Instacart+",
            domains: ["instacart.com"],
            senderPatterns: ["instacart"],
            iconName: "cart.fill",
            iconColor: Color(red: 67/255, green: 176/255, blue: 71/255),
            category: MerchantCategory.shopping,
            typicalPrices: [9.99, 99.00],
            typicalCycle: BillingCycle.monthly
        )
    ]

    // MARK: - Lookup Methods

    /// Find merchant by email domain
    func findMerchant(byDomain domain: String) -> MerchantInfo? {
        let lowercaseDomain = domain.lowercased()
        return merchants.first { merchant in
            merchant.domains.contains { lowercaseDomain.contains($0.lowercased()) }
        }
    }

    /// Find merchant by sender email
    func findMerchant(bySenderEmail email: String) -> MerchantInfo? {
        let lowercaseEmail = email.lowercased()

        // First try domain match
        if let atIndex = lowercaseEmail.lastIndex(of: "@") {
            let domain = String(lowercaseEmail[lowercaseEmail.index(after: atIndex)...])
            if let merchant = findMerchant(byDomain: domain) {
                return merchant
            }
        }

        // Then try pattern match
        return merchants.first { merchant in
            merchant.senderPatterns.contains { pattern in
                lowercaseEmail.contains(pattern.lowercased())
            }
        }
    }

    /// Find merchant by name or subject keywords
    func findMerchant(byKeyword keyword: String) -> MerchantInfo? {
        let lowercaseKeyword = keyword.lowercased()
        return merchants.first { merchant in
            merchant.name.lowercased().contains(lowercaseKeyword) ||
            merchant.senderPatterns.contains { lowercaseKeyword.contains($0.lowercased()) }
        }
    }

    /// Get default icon for unknown merchant
    func defaultIcon() -> (name: String, color: Color) {
        return ("creditcard.fill", .gray)
    }
}
