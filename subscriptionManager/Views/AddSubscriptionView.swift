//
//  AddSubscriptionView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/17/26.
//

import SwiftUI
import UIKit

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    let onSubscriptionAdded: (Subscription) -> Void
    let currentSubscriptionCount: Int

    @State private var searchText = ""
    @State private var selectedCompany: Company?
    @State private var selectedCategory: CompanyCategory?
    @State private var showPaywall = false

    // Check if user can add more subscriptions
    private var canAddSubscription: Bool {
        TierManager.shared.canAddSubscription(currentCount: currentSubscriptionCount)
    }

    // Fallback companies if JSON isn't loaded
    private var defaultCompanies: [Company] {
        [
            Company(id: "netflix", name: "Netflix", aliases: [], domains: ["netflix.com"], category: .streaming, brandColor: "#E50914", logoAssetName: "NetflixLogo"),
            Company(id: "spotify", name: "Spotify", aliases: [], domains: ["spotify.com"], category: .music, brandColor: "#1DB954", logoAssetName: "SpotifyLogo"),
            Company(id: "disney_plus", name: "Disney+", aliases: [], domains: ["disneyplus.com"], category: .streaming, brandColor: "#113CCF", logoAssetName: "DisneyPlusLogo"),
            Company(id: "youtube", name: "YouTube Premium", aliases: [], domains: ["youtube.com"], category: .streaming, brandColor: "#FF0000", logoAssetName: "YouTubeLogo"),
            Company(id: "hulu", name: "Hulu", aliases: [], domains: ["hulu.com"], category: .streaming, brandColor: "#1CE783", logoAssetName: "HuluLogo"),
            Company(id: "max", name: "Max", aliases: ["HBO Max"], domains: ["max.com"], category: .streaming, brandColor: "#002BE7", logoAssetName: "MaxLogo"),
            Company(id: "apple_music", name: "Apple Music", aliases: [], domains: ["apple.com"], category: .music, brandColor: "#FC3C44", logoAssetName: "AppleMusicLogo"),
            Company(id: "amazon_prime", name: "Amazon Prime", aliases: [], domains: ["amazon.com"], category: .streaming, brandColor: "#00A8E1", logoAssetName: "AmazonPrimeLogo"),
            Company(id: "chatgpt", name: "ChatGPT Plus", aliases: ["OpenAI"], domains: ["openai.com"], category: .ai, brandColor: "#10A37F", logoAssetName: "OpenAILogo"),
            Company(id: "adobe", name: "Adobe Creative Cloud", aliases: [], domains: ["adobe.com"], category: .productivity, brandColor: "#FF0000", logoAssetName: "AdobeLogo"),
            Company(id: "figma", name: "Figma", aliases: [], domains: ["figma.com"], category: .productivity, brandColor: "#F24E1E", logoAssetName: "FigmaLogo"),
            Company(id: "notion", name: "Notion", aliases: [], domains: ["notion.so"], category: .productivity, brandColor: "#000000", logoAssetName: "NotionLogo"),
            Company(id: "slack", name: "Slack", aliases: [], domains: ["slack.com"], category: .productivity, brandColor: "#4A154B", logoAssetName: "SlackLogo"),
            Company(id: "dropbox", name: "Dropbox", aliases: [], domains: ["dropbox.com"], category: .cloud, brandColor: "#0061FF", logoAssetName: "DropboxLogo"),
            Company(id: "icloud", name: "iCloud+", aliases: [], domains: ["icloud.com"], category: .cloud, brandColor: "#3693F3", logoAssetName: "iCloudLogo"),
            Company(id: "1password", name: "1Password", aliases: [], domains: ["1password.com"], category: .vpn, brandColor: "#0094F5", logoAssetName: "1PasswordLogo"),
            Company(id: "nordvpn", name: "NordVPN", aliases: [], domains: ["nordvpn.com"], category: .vpn, brandColor: "#4687FF", logoAssetName: "NordVPNLogo"),
            Company(id: "discord", name: "Discord Nitro", aliases: [], domains: ["discord.com"], category: .social, brandColor: "#5865F2", logoAssetName: "DiscordLogo"),
            Company(id: "linkedin", name: "LinkedIn Premium", aliases: [], domains: ["linkedin.com"], category: .social, brandColor: "#0A66C2", logoAssetName: "LinkedInLogo"),
            Company(id: "xbox", name: "Xbox Game Pass", aliases: [], domains: ["xbox.com"], category: .gaming, brandColor: "#107C10", logoAssetName: "XboxLogo"),
            Company(id: "playstation", name: "PlayStation Plus", aliases: [], domains: ["playstation.com"], category: .gaming, brandColor: "#003791", logoAssetName: "PlayStationLogo"),
            Company(id: "twitch", name: "Twitch", aliases: [], domains: ["twitch.tv"], category: .gaming, brandColor: "#9146FF", logoAssetName: "TwitchLogo"),
            Company(id: "strava", name: "Strava", aliases: [], domains: ["strava.com"], category: .fitness, brandColor: "#FC4C02", logoAssetName: "StravaLogo"),
            Company(id: "headspace", name: "Headspace", aliases: [], domains: ["headspace.com"], category: .fitness, brandColor: "#F47D31", logoAssetName: "HeadspaceLogo"),
            Company(id: "duolingo", name: "Duolingo Plus", aliases: [], domains: ["duolingo.com"], category: .education, brandColor: "#58CC02", logoAssetName: "DuolingoLogo"),
            Company(id: "masterclass", name: "MasterClass", aliases: [], domains: ["masterclass.com"], category: .education, brandColor: "#000000", logoAssetName: "MasterClassLogo"),
            Company(id: "nytimes", name: "The New York Times", aliases: [], domains: ["nytimes.com"], category: .news, brandColor: "#000000", logoAssetName: "NYTimesLogo"),
            Company(id: "medium", name: "Medium", aliases: [], domains: ["medium.com"], category: .news, brandColor: "#000000", logoAssetName: "MediumLogo"),
            Company(id: "doordash", name: "DoorDash DashPass", aliases: [], domains: ["doordash.com"], category: .food, brandColor: "#FF3008", logoAssetName: "DoorDashLogo"),
            Company(id: "ubereats", name: "Uber One", aliases: [], domains: ["uber.com"], category: .food, brandColor: "#06C167", logoAssetName: "UberEatsLogo"),
        ]
    }

    private var companies: [Company] {
        let loaded = CompanyLogoService.shared.companies
        return loaded.isEmpty ? defaultCompanies : loaded
    }

    private var filteredCompanies: [Company] {
        var list = companies
        if let selectedCategory {
            list = list.filter { $0.category == selectedCategory }
        }
        if searchText.isEmpty {
            return list.sorted { $0.name < $1.name }
        }
        let query = searchText
        return list.filter { $0.matches(query: query) }
            .sorted { $0.name < $1.name }
    }

    private var groupedCompanies: [CompanyCategory: [Company]] {
        Dictionary(grouping: filteredCompanies, by: \.category)
            .mapValues { $0.sorted { $0.name < $1.name } }
    }

    private var availableCategories: [CompanyCategory] {
        CompanyCategory.allCases.filter { groupedCompanies[$0]?.isEmpty == false }
    }

    private var chipCategories: [CompanyCategory] {
        let present = Set(companies.map { $0.category })
        return CompanyCategory.allCases.filter { present.contains($0) }
    }

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                categoryChips
                    .padding(.bottom, 16)

                companyList
            }
        }
        .navigationTitle("Add Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(Color(red: 0.11, green: 0.11, blue: 0.12), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedCompany) { company in
            SubscriptionDetailEntryView(
                company: company,
                cardColor: cardColorForCompany(company),
                onSubscriptionAdded: onSubscriptionAdded,
                onSave: {
                    dismiss()
                }
            )
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            // If user dismissed paywall without upgrading, go back
            if !canAddSubscription {
                dismiss()
            }
        }) {
            PaywallView(
                trigger: .subscriptionLimit,
                onContinueFree: nil,
                onPurchaseSuccess: {
                    // After successful purchase, user can continue adding
                }
            )
        }
        .onAppear {
            // Show paywall if user has reached limit
            if !canAddSubscription {
                showPaywall = true
            }
        }
    }

    // MARK: - Color Assignment

    private func cardColorForCompany(_ company: Company) -> Color {
        // Use a hash of the company ID to get a consistent color
        // This matches the HomeViewModel's colorIndexForMerchantId approach
        let hash = abs(company.id.hashValue)
        let colorIndex = hash % SubscriptionCardColors.cardRotation.count
        return SubscriptionCardColors.cardRotation[colorIndex]
    }

    // MARK: - Company List

    private var companyList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                ForEach(availableCategories, id: \.self) { category in
                    categorySection(for: category, companies: groupedCompanies[category] ?? [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private func categorySection(for category: CompanyCategory, companies: [Company]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(categoryTitle(category))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(companies.indices, id: \.self) { index in
                    let company = companies[index]
                    CompanyRowView(company: company)
                        .onTapGesture {
                            selectedCompany = company
                        }

                    if index < companies.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(chipCategories, id: \.self) { category in
                    categoryChip(title: categoryTitle(category), isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func categoryTitle(_ category: CompanyCategory) -> String {
        switch category {
        case .ai:
            return "AI"
        default:
            return category.rawValue
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            TextField("", text: $searchText, prompt: Text("Streaming, Music, Games and More...").foregroundColor(.white.opacity(0.4)))
                .font(.system(size: 16))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .autocapitalization(.none)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Company Row View

struct CompanyRowView: View {
    let company: Company

    var body: some View {
        HStack(spacing: 16) {
            // Logo - load directly from asset name
            logoView
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Name
            Text(company.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var logoView: some View {
        if let assetName = company.logoAssetName,
           let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback placeholder with initials
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(company.color.opacity(0.15))
                Text(initials)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(company.color)
            }
        }
    }

    private var initials: String {
        let words = company.name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

// MARK: - Subscription Detail Entry View

struct SubscriptionDetailEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let company: Company
    let cardColor: Color
    let onSubscriptionAdded: (Subscription) -> Void
    var onSave: (() -> Void)?

    @State private var price: String = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var nextBillingDate = Date()

    // MARK: - Theme Constants

    private let backgroundColor = Color(red: 0.07, green: 0.07, blue: 0.08)
    private let dividerColor = Color.black.opacity(0.08)
    private let cardCornerRadius: CGFloat = 28

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Main colored card
                        mainCard

                        // Add button outside the card
                        addButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Add Details")
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
                    Text("Add Details")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            // Header with logo and name
            headerSection
                .padding(.bottom, 20)

            sectionDivider

            // Form fields
            formSection
        }
        .padding(20)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Logo
            companyLogoImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Name and category
            VStack(alignment: .leading, spacing: 6) {
                Text(company.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)

                Text(company.category.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.5))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var companyLogoImage: some View {
        if let assetName = company.logoAssetName,
           let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.1))
                .overlay(
                    Text(companyInitials)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black.opacity(0.5))
                )
        }
    }

    private var companyInitials: String {
        let words = company.name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 0) {
            // Price row
            HStack {
                Text("Price")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()

                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black.opacity(0.5))

                    TextField("", text: $price, prompt: Text("0.00").foregroundColor(.black.opacity(0.3)))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                }
            }
            .padding(.vertical, 14)

            rowDivider

            // Billing Cycle row
            HStack {
                Text("Billing Cycle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()

                Picker("", selection: $billingCycle) {
                    Text("Weekly").tag(BillingCycle.weekly)
                    Text("Monthly").tag(BillingCycle.monthly)
                    Text("Quarterly").tag(BillingCycle.quarterly)
                    Text("Yearly").tag(BillingCycle.yearly)
                }
                .pickerStyle(.menu)
                .tint(.black.opacity(0.85))
            }
            .padding(.vertical, 14)

            rowDivider

            // Next Billing Date row
            HStack {
                Text("Next Billing")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()

                DatePicker("", selection: $nextBillingDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.black.opacity(0.85))
            }
            .padding(.vertical, 11)
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: saveSubscription) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text("Add Subscription")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Dividers

    private var sectionDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 1)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: - Save Action

    private func saveSubscription() {
        let priceValue = Double(price) ?? 0.0

        let subscription = Subscription(
            merchantId: company.id,
            name: company.name,
            price: priceValue,
            billingCycle: billingCycle,
            confidence: .high,
            nextBillingDate: nextBillingDate,
            lastChargeDate: nil,
            emailCount: 0,
            senderEmail: company.domains.first ?? "",
            detectedAt: Date(),
            detectionSource: .manual
        )

        onSubscriptionAdded(subscription)
        dismiss()
        onSave?()
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    AddSubscriptionView(onSubscriptionAdded: { _ in }, currentSubscriptionCount: 3)
}
