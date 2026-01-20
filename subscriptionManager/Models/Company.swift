//
//  Company.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/17/26.
//

import Foundation
import SwiftUI

// MARK: - Company Category

enum CompanyCategory: String, Codable, CaseIterable {
    case streaming = "Streaming"
    case music = "Music"
    case gaming = "Gaming"
    case productivity = "Productivity"
    case cloud = "Cloud Storage"
    case fitness = "Fitness"
    case news = "News & Media"
    case education = "Education"
    case finance = "Finance"
    case food = "Food & Delivery"
    case shopping = "Shopping"
    case social = "Social"
    case utilities = "Utilities"
    case vpn = "VPN & Security"
    case ai = "AI & Tools"
    case other = "Other"

    var icon: String {
        switch self {
        case .streaming: return "play.tv"
        case .music: return "music.note"
        case .gaming: return "gamecontroller"
        case .productivity: return "briefcase"
        case .cloud: return "cloud"
        case .fitness: return "figure.run"
        case .news: return "newspaper"
        case .education: return "book"
        case .finance: return "dollarsign.circle"
        case .food: return "fork.knife"
        case .shopping: return "cart"
        case .social: return "person.2"
        case .utilities: return "wrench.and.screwdriver"
        case .vpn: return "lock.shield"
        case .ai: return "brain"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Company Model

struct Company: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let domains: [String]
    let category: CompanyCategory
    let brandColor: String?
    let logoAssetName: String?

    /// All searchable terms for this company (name + aliases + domains)
    var searchTerms: [String] {
        var terms = [name.lowercased()]
        terms.append(contentsOf: aliases.map { $0.lowercased() })
        terms.append(contentsOf: domains.map { $0.lowercased() })
        return terms
    }

    /// Brand color as SwiftUI Color
    var color: Color {
        guard let hex = brandColor else { return .gray }
        return Color(hex: hex) ?? .gray
    }

    /// Check if this company matches a search query
    func matches(query: String) -> Bool {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return searchTerms.contains { term in
            term.contains(lowercasedQuery) || lowercasedQuery.contains(term)
        }
    }

    /// Match score (higher = better match)
    func matchScore(for query: String) -> Int {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact name match
        if name.lowercased() == lowercasedQuery { return 100 }

        // Exact alias match
        if aliases.map({ $0.lowercased() }).contains(lowercasedQuery) { return 90 }

        // Exact domain match
        if domains.map({ $0.lowercased() }).contains(lowercasedQuery) { return 85 }

        // Name starts with query
        if name.lowercased().hasPrefix(lowercasedQuery) { return 80 }

        // Alias starts with query
        if aliases.contains(where: { $0.lowercased().hasPrefix(lowercasedQuery) }) { return 70 }

        // Name contains query
        if name.lowercased().contains(lowercasedQuery) { return 60 }

        // Alias contains query
        if aliases.contains(where: { $0.lowercased().contains(lowercasedQuery) }) { return 50 }

        // Domain contains query
        if domains.contains(where: { $0.lowercased().contains(lowercasedQuery) }) { return 40 }

        return 0
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        switch length {
        case 6:
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8:
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }
}
