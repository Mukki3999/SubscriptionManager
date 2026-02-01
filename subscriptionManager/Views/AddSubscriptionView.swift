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
    let previewCardColor: Color

    @StateObject private var companyService = CompanyLogoService.shared
    @State private var searchText = ""
    @State private var selectedCompany: Company?
    @State private var selectedCategory: CompanyCategory?
    @State private var showPaywall = false

    init(
        onSubscriptionAdded: @escaping (Subscription) -> Void,
        currentSubscriptionCount: Int,
        previewCardColor: Color = SubscriptionCardColors.softBlue
    ) {
        self.onSubscriptionAdded = onSubscriptionAdded
        self.currentSubscriptionCount = currentSubscriptionCount
        self.previewCardColor = previewCardColor
    }

    // Check if user can add more subscriptions
    private var canAddSubscription: Bool {
        TierManager.shared.canAddSubscription(currentCount: currentSubscriptionCount)
    }

    // All companies - hardcoded for reliability
    private var defaultCompanies: [Company] {
        CompanyCatalog.all
    }

    private var companies: [Company] {
        let loaded = companyService.companies
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
        return CompanyCategory.allCases
            .filter { present.contains($0) }
            .sorted { categoryTitle($0) < categoryTitle($1) }
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
                cardColor: previewCardColor,
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
            PaywallContainerView(
                trigger: .subscriptionLimit,
                onContinueFree: nil,
                onPurchaseSuccess: {
                    // After successful purchase, user can continue adding
                }
            )
        }
        .onAppear {
            AnalyticsService.screen("add_subscription")
            AnalyticsService.event("add_subscription_view")
            // Show paywall if user has reached limit
            if !canAddSubscription {
                showPaywall = true
            }
        }
        .onChange(of: showPaywall) { _, isShowing in
            if isShowing {
                AnalyticsService.event("add_subscription_paywall_triggered")
            }
        }
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
                            AnalyticsService.event("add_subscription_company_selected", params: [
                                "company_id": company.id
                            ])
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
    @State private var selectedReminderDays: Int = 3
    @State private var showReminderPaywall = false
    @State private var showPriceError = false

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
            .fullScreenCover(isPresented: $showReminderPaywall) {
                PaywallContainerView(trigger: .featureGate("Custom Reminders"))
            }
            .alert("Price can't be empty", isPresented: $showPriceError) {
                Button("OK", role: .cancel) {}
            }
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

            rowDivider

            // Reminder row
            reminderRow
        }
    }

    // MARK: - Reminder Row

    private var reminderRow: some View {
        HStack {
            Text("Remind me")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black.opacity(0.6))

            Spacer()

            if TierManager.shared.currentTier.canCustomizeNotifications {
                // Pro users: Picker with options
                Picker("", selection: $selectedReminderDays) {
                    Text("1 day before").tag(1)
                    Text("3 days before").tag(3)
                    Text("7 days before").tag(7)
                }
                .pickerStyle(.menu)
                .tint(.black.opacity(0.85))
            } else {
                // Free users: Locked with PRO badge
                Button {
                    showReminderPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Text("3 days before")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black.opacity(0.4))

                        reminderProBadge
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
    }

    private var reminderProBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .bold))
            Text("PRO")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(red: 0.78, green: 0.93, blue: 0.87)))
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.85))
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
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrice.isEmpty, let priceValue = Double(trimmedPrice), priceValue > 0 else {
            showPriceError = true
            return
        }

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

        // Schedule notification with selected reminder days
        Task {
            await NotificationService.shared.scheduleRenewalNotification(
                for: subscription,
                daysBeforeRenewal: selectedReminderDays
            )
        }

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
