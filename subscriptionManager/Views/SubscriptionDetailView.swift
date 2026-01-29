//
//  SubscriptionDetailView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/18/26.
//

import SwiftUI

// MARK: - Subscription Detail View

struct SubscriptionDetailView: View {

    // MARK: - Properties

    @StateObject private var viewModel: SubscriptionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCancellationSteps = false
    @State private var showDeleteConfirmation = false
    @State private var showPriceEditor = false
    @State private var editedPrice: String = ""
    @State private var currentSubscription: Subscription

    let subscription: Subscription
    let logoImage: String?
    let cardColor: Color
    let showsCancellationSection: Bool
    let showsFromRow: Bool
    let showsManageButton: Bool
    var onDelete: (() -> Void)?
    var onUpdate: ((Subscription) -> Void)?

    // MARK: - Theme Constants

    private let backgroundColor = Color(red: 0.07, green: 0.07, blue: 0.08)
    private let dividerColor = Color.black.opacity(0.08)
    private let cardCornerRadius: CGFloat = 28

    // MARK: - Initialization

    init(
        subscription: Subscription,
        logoImage: String? = nil,
        cardColor: Color = SubscriptionCardColors.softBlue,
        showsCancellationSection: Bool = true,
        showsFromRow: Bool = true,
        showsManageButton: Bool = true,
        onDelete: (() -> Void)? = nil,
        onUpdate: ((Subscription) -> Void)? = nil
    ) {
        self.subscription = subscription
        self._currentSubscription = State(initialValue: subscription)
        self.logoImage = logoImage
        self.cardColor = cardColor
        self.showsCancellationSection = showsCancellationSection
        self.showsFromRow = showsFromRow
        self.showsManageButton = showsManageButton
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        _viewModel = StateObject(wrappedValue: SubscriptionDetailViewModel(subscription: subscription))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Main colored card containing everything
                        mainCard

                        // Remove subscription (outside the card)
                        deleteButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
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
                    Text("Subscription")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Sign in may be required", isPresented: $viewModel.showWebCancelInterstitial) {
            Button("Continue to Website") {
                viewModel.confirmAndOpenCancelURL()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You may need to sign in to your \(viewModel.subscriptionName) account to manage your subscription.")
        }
        .confirmationDialog("Delete Subscription", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(viewModel.subscriptionName) from your tracked subscriptions.")
        }
        .sheet(isPresented: $showPriceEditor) {
            priceEditorSheet
        }
    }

    // MARK: - Price Editor Sheet

    private var priceEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Edit Price")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Enter the correct subscription price")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 20)

                // Price input field
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    TextField("0.00", text: $editedPrice)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 150)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 40)

                Spacer()

                // Save button
                Button(action: savePrice) {
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showPriceEditor = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    private func savePrice() {
        // Parse the price and validate
        let cleanedPrice = editedPrice.replacingOccurrences(of: ",", with: ".")
        guard let newPrice = Double(cleanedPrice), newPrice > 0 else {
            return
        }

        // Update the subscription
        var updatedSubscription = currentSubscription
        updatedSubscription.price = newPrice
        currentSubscription = updatedSubscription

        // Notify parent to persist the change
        onUpdate?(updatedSubscription)

        showPriceEditor = false
    }

    // MARK: - Main Colored Card

    private var mainCard: some View {
        VStack(spacing: 0) {
            // Header section
            headerSection
                .padding(.bottom, 20)

            divider

            // Subscription info section
            subscriptionInfoSection

            divider

            // Settings section
            settingsSection

            // Cancellation steps (if available)
            if showsCancellationSection, let steps = viewModel.cancellationSteps, !steps.isEmpty {
                divider
                cancellationSection(steps: steps)
            }

            // Related emails section
            if viewModel.isUnknownSubscription || viewModel.hasRelatedEmails {
                divider
                emailsSection
            }

            // Reminder banner (if applicable)
            if let days = viewModel.daysUntilNextBilling, let nextDate = viewModel.nextBillingDateFormatted {
                reminderBanner(days: days, nextDate: nextDate)
                    .padding(.top, 16)
            }

            // Manage button
            if showsManageButton {
                manageButton
                    .padding(.top, 20)
            }
        }
        .padding(20)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Logo
            Group {
                if let logoImage = logoImage, UIImage(named: logoImage) != nil {
                    Image(logoImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.1))
                        .overlay(
                            Text(String(viewModel.subscriptionName.prefix(1)).uppercased())
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black.opacity(0.5))
                        )
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Name and price
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.subscriptionName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)

                Text(viewModel.subscriptionPriceWithCycle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
            }

            Spacer()
        }
    }

    // MARK: - Subscription Info Section

    private var subscriptionInfoSection: some View {
        VStack(spacing: 0) {
            editablePriceRow

            rowDivider

            infoRow(title: "Billing Cycle", value: viewModel.subscriptionBillingCycle)

            if viewModel.nextBillingDateFormatted != nil {
                rowDivider

                infoRow(
                    title: "Next Billing",
                    value: viewModel.nextBillingDateFormatted ?? "—",
                    badge: viewModel.daysUntilNextBilling.map { "\($0)d" }
                )
            }

            rowDivider

            infoRow(title: "Started", value: formatDate(subscription.detectedAt))
        }
    }

    // MARK: - Editable Price Row

    private var editablePriceRow: some View {
        Button(action: {
            editedPrice = String(format: "%.2f", currentSubscription.price)
            showPriceEditor = true
        }) {
            HStack(spacing: 12) {
                Text("Price")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))

                Spacer()

                HStack(spacing: 8) {
                    Text(currentSubscription.formattedPrice)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))

                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            infoRow(
                title: "Detected From",
                value: viewModel.detectionSourceLabel,
                icon: detectionSourceIcon
            )

            rowDivider

            infoRow(
                title: "Managed Via",
                value: managementTypeLabel,
                icon: managementTypeIcon
            )

            if showsFromRow, viewModel.senderEmailLooksValid {
                rowDivider

                infoRow(
                    title: "From",
                    value: formatEmail(viewModel.senderEmail)
                )
            }
        }
    }

    // MARK: - Cancellation Section

    private func cancellationSection(steps: [String]) -> some View {
        VStack(spacing: 0) {
            // Header with toggle
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showCancellationSteps.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.5))

                    Text("How to Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black.opacity(0.8))

                    Spacer()

                    Image(systemName: showCancellationSteps ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.4))
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expandable steps
            if showCancellationSteps {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.black.opacity(0.7)))

                            Text(step)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.black.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Emails Section

    private var emailsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "envelope")
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.5))

                Text("Related Emails")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))

                Spacer()

                if viewModel.isLoadingEmails {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black.opacity(0.5)))
                        .scaleEffect(0.7)
                } else if !viewModel.hasRelatedEmails && viewModel.isUnknownSubscription {
                    Button(action: {
                        Task { await viewModel.searchRelatedEmails() }
                    }) {
                        Text("Search")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 14)

            if viewModel.hasRelatedEmails {
                VStack(spacing: 8) {
                    ForEach(viewModel.relatedEmails.prefix(3)) { email in
                        emailRow(email: email)
                    }
                }
                .padding(.bottom, 14)
            }

            if let error = viewModel.emailSearchError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.bottom, 14)
            }
        }
    }

    private func emailRow(email: GmailMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(email.subject)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black.opacity(0.85))
                .lineLimit(1)

            HStack {
                Text(email.from)
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.5))
                    .lineLimit(1)

                Spacer()

                Text(formatDate(email.date))
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Reminder Banner

    private func reminderBanner(days: Int, nextDate: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.7))

            Text("You'll be charged \(viewModel.subscriptionPrice) on \(nextDate)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black.opacity(0.7))

            Spacer()
        }
        .padding(12)
        .background(Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Manage Button

    private var manageButton: some View {
        Button(action: { viewModel.handleManageSubscription() }) {
            HStack(spacing: 10) {
                Image(systemName: manageButtonIcon)
                    .font(.system(size: 16, weight: .semibold))

                Text(viewModel.manageButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(cardColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var manageButtonIcon: String {
        switch viewModel.managementType {
        case .appStore:
            return "gear"
        case .web:
            return "safari"
        case .unknown:
            return "magnifyingglass"
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))

                Text("Remove Subscription")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Components

    private var divider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 1)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
    }

    private func infoRow(
        title: String,
        value: String,
        icon: String? = nil,
        badge: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.5))
                    .frame(width: 20)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black.opacity(0.6))

            Spacer()

            HStack(spacing: 8) {
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.black.opacity(0.6))
                        )
                }

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - Computed Properties

    private var detectionSourceIcon: String {
        switch subscription.detectionSource {
        case .gmail:
            return "envelope.fill"
        case .appStore:
            return "apple.logo"
        case .manual:
            return "hand.draw.fill"
        }
    }

    private var managementTypeIcon: String {
        switch viewModel.managementType {
        case .appStore:
            return "apple.logo"
        case .web:
            return "globe"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var managementTypeLabel: String {
        switch viewModel.managementType {
        case .appStore:
            return "App Store"
        case .web:
            return "Web"
        case .unknown:
            return "Unknown"
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatEmail(_ email: String) -> String {
        if email.count > 25 {
            return String(email.prefix(23)) + "..."
        }
        return email
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
    SubscriptionDetailView(
        subscription: Subscription(
            merchantId: "netflix",
            name: "Netflix",
            price: 15.99,
            billingCycle: .monthly,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
            senderEmail: "info@netflix.com"
        ),
        logoImage: "NetflixLogo",
        cardColor: SubscriptionCardColors.softBlue
    )
}
