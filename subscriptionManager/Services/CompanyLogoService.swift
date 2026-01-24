//
//  CompanyLogoService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/17/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Logo.dev API Configuration

private enum LogoDevAPI {
    static let publicKey = "pk_GnS2mn37SQqL090jtbraTw"
    static let baseURL = "https://img.logo.dev"

    static func url(for domain: String, size: Int = 512) -> URL? {
        URL(string: "\(baseURL)/\(domain)?token=\(publicKey)&format=png&size=\(size)")
    }
}

// MARK: - Company Logo Service

@MainActor
final class CompanyLogoService: ObservableObject {
    static let shared = CompanyLogoService()

    @Published private(set) var companies: [Company] = []
    @Published private(set) var isLoaded = false

    /// In-memory cache for downloaded logo images
    private var imageCache: [String: UIImage] = [:]

    /// Cache directory for persistent storage
    private let cacheDirectory: URL

    private init() {
        // Set up cache directory
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("CompanyLogos", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load companies database
        loadCompaniesDatabase()
    }

    // MARK: - Database Loading

    private func loadCompaniesDatabase() {
        companies = CompanyCatalog.all
        isLoaded = true
        print("CompanyLogoService: Loaded \(companies.count) companies (bundled catalog)")
    }

    // MARK: - Company Matching

    /// Find the best matching company for a search query
    func findCompany(for query: String) -> Company? {
        guard !query.isEmpty else { return nil }

        let matches = companies
            .map { (company: $0, score: $0.matchScore(for: query)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }

        return matches.first?.company
    }

    /// Find all companies matching a query (for autocomplete)
    func findCompanies(matching query: String, limit: Int = 10) -> [Company] {
        guard !query.isEmpty else { return [] }

        return companies
            .map { (company: $0, score: $0.matchScore(for: query)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.company }
    }

    /// Find company by exact ID
    func company(withId id: String) -> Company? {
        companies.first { $0.id == id }
    }

    /// Find company by domain
    func company(forDomain domain: String) -> Company? {
        let cleanDomain = domain.lowercased()
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        return companies.first { company in
            company.domains.contains { $0.lowercased() == cleanDomain }
        }
    }

    /// Find company by email sender domain
    func company(forEmail email: String) -> Company? {
        guard let domain = email.split(separator: "@").last else { return nil }
        return company(forDomain: String(domain))
    }

    // MARK: - Logo Retrieval (Assets First, API Fallback)

    /// Get logo for a company - checks assets first, then falls back to API
    /// Returns UIImage for flexibility in both SwiftUI and UIKit contexts
    func logo(for company: Company) async -> UIImage? {
        // 1. Try local asset first
        if let assetName = company.logoAssetName,
           let assetImage = UIImage(named: assetName) {
            return assetImage
        }

        // 2. Try to get from API using primary domain
        guard let domain = company.domains.first else { return nil }
        return await fetchLogo(forDomain: domain)
    }

    /// Get logo for a domain directly (useful for unknown companies)
    func logo(forDomain domain: String) async -> UIImage? {
        // Check if we have a known company for this domain
        if let company = company(forDomain: domain) {
            return await logo(for: company)
        }

        // Otherwise fetch directly from API
        return await fetchLogo(forDomain: domain)
    }

    /// Get logo from the API only, bypassing local assets.
    func remoteLogo(forDomain domain: String) async -> UIImage? {
        await fetchLogo(forDomain: domain)
    }

    /// Get logo by company name/query
    func logo(forQuery query: String) async -> UIImage? {
        if let company = findCompany(for: query) {
            return await logo(for: company)
        }
        return nil
    }

    /// Synchronous check for local asset only (no API call)
    func localLogo(for company: Company) -> UIImage? {
        guard let assetName = company.logoAssetName else { return nil }
        return UIImage(named: assetName)
    }

    /// Synchronous check for local asset by name
    func localLogo(assetName: String) -> UIImage? {
        return UIImage(named: assetName)
    }

    // MARK: - API Fetching with Caching

    /// Fetch logo from Logo.dev API with caching
    private func fetchLogo(forDomain domain: String) async -> UIImage? {
        let cleanDomain = domain.lowercased()
            .replacingOccurrences(of: "www.", with: "")

        // 1. Check in-memory cache
        if let cached = imageCache[cleanDomain] {
            return cached
        }

        // 2. Check disk cache
        let cacheFile = cacheDirectory.appendingPathComponent("\(cleanDomain).png")
        if let cachedData = try? Data(contentsOf: cacheFile),
           let image = UIImage(data: cachedData) {
            imageCache[cleanDomain] = image
            return image
        }

        // 3. Fetch from API
        guard let url = LogoDevAPI.url(for: cleanDomain) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }

            // Cache to memory
            imageCache[cleanDomain] = image

            // Cache to disk
            try? data.write(to: cacheFile)

            return image
        } catch {
            print("CompanyLogoService: Failed to fetch logo for \(domain) - \(error)")
            return nil
        }
    }

    // MARK: - Cache Management

    /// Clear all cached logos
    func clearCache() {
        imageCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Preload logos for a list of companies (useful for batch operations)
    func preloadLogos(for companies: [Company]) async {
        await withTaskGroup(of: Void.self) { group in
            for company in companies {
                group.addTask {
                    _ = await self.logo(for: company)
                }
            }
        }
    }

    // MARK: - Placeholder Generation

    /// Generate initials from a name
    func generateInitials(from name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let first = words[0].prefix(1)
            let second = words[1].prefix(1)
            return "\(first)\(second)".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    // MARK: - Categories

    /// Get all companies in a category
    func companies(in category: CompanyCategory) -> [Company] {
        companies.filter { $0.category == category }
    }

    /// Get all unique categories that have companies
    var availableCategories: [CompanyCategory] {
        Array(Set(companies.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Company Logo View Component

/// A SwiftUI view that displays a company logo with automatic fallback to API
struct CompanyLogoView: View {
    let companyName: String
    var domain: String? = nil
    var size: CGFloat = 40
    var cornerRadius: CGFloat? = nil

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false

    private var company: Company? {
        CompanyLogoService.shared.findCompany(for: companyName)
    }

    private var effectiveCornerRadius: CGFloat {
        cornerRadius ?? (size * 0.2)
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                // Placeholder with initials
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
        .task {
            await loadLogo()
        }
    }

    private var placeholderView: some View {
        let color = company?.color ?? .gray
        let initials = CompanyLogoService.shared.generateInitials(from: companyName)

        return ZStack {
            RoundedRectangle(cornerRadius: effectiveCornerRadius)
                .fill(color.opacity(0.15))

            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private func loadLogo() async {
        guard image == nil, !isLoading, !hasFailed else { return }

        isLoading = true
        defer { isLoading = false }

        let service = CompanyLogoService.shared

        // Try to get logo for company
        if let company = company {
            if let logo = await service.logo(for: company) {
                self.image = logo
                return
            }
        }

        // Try domain if provided
        if let domain = domain {
            if let logo = await service.logo(forDomain: domain) {
                self.image = logo
                return
            }
        }

        // Mark as failed to prevent retries
        hasFailed = true
    }
}

// MARK: - Domain-based Logo View

/// A SwiftUI view that displays a logo for a domain directly
struct DomainLogoView: View {
    let domain: String
    var size: CGFloat = 40
    var cornerRadius: CGFloat? = nil
    var placeholderName: String? = nil
    var preferRemote: Bool = false

    @State private var image: UIImage?
    @State private var isLoading = false

    private var effectiveCornerRadius: CGFloat {
        cornerRadius ?? (size * 0.2)
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
        .task {
            await loadLogo()
        }
    }

    private var placeholderView: some View {
        let name = placeholderName ?? domain
        let initials = CompanyLogoService.shared.generateInitials(from: name)
        let company = CompanyLogoService.shared.company(forDomain: domain)
        let color = company?.color ?? .gray

        return ZStack {
            RoundedRectangle(cornerRadius: effectiveCornerRadius)
                .fill(color.opacity(0.15))

            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private func loadLogo() async {
        guard image == nil, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let service = CompanyLogoService.shared
        let logo = preferRemote
            ? await service.remoteLogo(forDomain: domain)
            : await service.logo(forDomain: domain)

        if let logo {
            self.image = logo
        }
    }
}

// MARK: - Preview

#Preview("Company Logos") {
    VStack(spacing: 20) {
        // Known companies (will use local assets)
        HStack(spacing: 16) {
            CompanyLogoView(companyName: "Netflix", size: 60)
            CompanyLogoView(companyName: "Spotify", size: 60)
            CompanyLogoView(companyName: "Disney+", size: 60)
        }

        // Unknown company (will show placeholder or fetch from API)
        HStack(spacing: 16) {
            CompanyLogoView(companyName: "Unknown App", size: 60)
            DomainLogoView(domain: "stripe.com", size: 60)
        }
    }
    .padding()
}
