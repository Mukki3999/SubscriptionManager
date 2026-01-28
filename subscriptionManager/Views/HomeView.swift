//
//  HomeView.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import SwiftUI
import UIKit

// MARK: - Drag State

/// Tracks the current drag state for reordering subscription cards.
enum DragState {
    case inactive
    case pressing(index: Int)
    case dragging(index: Int, translation: CGFloat)

    var isDragging: Bool {
        switch self {
        case .dragging: return true
        default: return false
        }
    }

    var draggedIndex: Int? {
        switch self {
        case .pressing(let index), .dragging(let index, _):
            return index
        case .inactive:
            return nil
        }
    }

    var translation: CGFloat {
        switch self {
        case .dragging(_, let translation):
            return translation
        default:
            return 0
        }
    }
}

// MARK: - Home View

/// Main home screen displaying user's subscriptions with upcoming bills and full list.
struct HomeView: View {

    // MARK: - State

    @StateObject private var companyService = CompanyLogoService.shared
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @State private var isBalanceHidden = false
    @State private var userName = ""
    @FocusState private var isNameFocused: Bool
    @State private var profileImageData: Data?
    @State private var showAddSubscription = false
    @State private var showNotifications = false
    @State private var showSettings = false
    @State private var selectedSubscription: Subscription?
    @State private var showInsights = false
    @State private var showInsightsPaywall = false
    @State private var showAllUpcomingBills = false
    @GestureState private var dragState: DragState = .inactive

    // MARK: - Constants

    private let horizontalPadding: CGFloat = 24
    private let darkBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let mintBackground = Color(red: 0.78, green: 0.93, blue: 0.87)
    private let profileNameKey = "userProfile.name"
    private let profileImageKey = "userProfile.imageData"
    private let hasSeenNameCalloutKey = "userProfile.hasSeenNameCallout"

    // MARK: - Body

    var body: some View {
        let _ = companyService.isLoaded
        NavigationStack {
            ZStack {
                // Solid dark background that extends full screen
                darkBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Dark section (greeting, balance, upcoming bills)
                        darkSection

                        // Mint section (subscriptions list)
                        mintSection
                    }
                }
                .scrollDisabled(dragState.isDragging)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showAddSubscription) {
                AddSubscriptionView(
                    onSubscriptionAdded: { subscription in
                        viewModel.addSubscription(subscription)
                    },
                    currentSubscriptionCount: viewModel.subscriptionCount,
                    previewCardColor: viewModel.nextAvailableCardColor()
                )
            }
            .onAppear {
                AnalyticsService.screen("home")
                viewModel.loadSubscriptions()
                loadProfile()
                notificationViewModel.loadNotifications()
            }
            .onChange(of: userName) { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    UserDefaults.standard.removeObject(forKey: profileNameKey)
                } else {
                    UserDefaults.standard.set(trimmed, forKey: profileNameKey)
                }
            }
            .onChange(of: showNotifications) { isShowing in
                if !isShowing {
                    // Refresh notification state when sheet is dismissed
                    notificationViewModel.loadNotifications()
                }
            }
            .onChange(of: viewModel.allSubscriptions) { subscriptions in
                // Generate notifications when subscriptions are loaded/changed
                notificationViewModel.generateNotificationsForUpcomingRenewals(from: subscriptions)
                notificationViewModel.scheduleSystemNotifications(for: subscriptions)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(profileImageData: $profileImageData)
            }
            .sheet(item: $selectedSubscription) { subscription in
                SubscriptionDetailView(
                    subscription: subscription,
                    logoImage: subscriptionLogoImage(for: subscription),
                    cardColor: cardColorForSubscription(subscription),
                    onDelete: {
                        viewModel.deleteSubscription(subscription)
                    },
                    onUpdate: { updatedSubscription in
                        viewModel.updateSubscription(updatedSubscription)
                    }
                )
            }
            .navigationDestination(isPresented: $showInsights) {
                InsightsView(
                    subscriptions: viewModel.allSubscriptions,
                    colorIndices: viewModel.colorIndices
                )
            }
            .fullScreenCover(isPresented: $showInsightsPaywall) {
                PaywallView(
                    trigger: .featureGate("Insights"),
                    onPurchaseSuccess: {
                        showInsights = true
                    }
                )
            }
            .sheet(isPresented: $showAllUpcomingBills) {
                AllUpcomingBillsView(
                    subscriptions: viewModel.allSubscriptions,
                    colorIndices: viewModel.colorIndices,
                    onSelectSubscription: { subscription in
                        showAllUpcomingBills = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedSubscription = subscription
                        }
                    }
                )
            }
        }
    }

    // MARK: - Dark Section

    private var darkSection: some View {
        VStack(spacing: 0) {
            // Safe area spacing
            Color.clear.frame(height: 60)

            // Greeting row
            greetingRow
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 24)

            // Balance card with integrated donut chart
            BalanceCardView(
                balance: displayBalance,
                billingDate: viewModel.billingPeriodEnd,
                isBalanceHidden: $isBalanceHidden,
                chartItems: buildChartItems(),
                isPro: TierManager.shared.currentTier.canViewInsights,
                onChartTap: {
                    AnalyticsService.event("spending_chart_tapped")
                    if TierManager.shared.currentTier.canViewInsights {
                        showInsights = true
                    } else {
                        showInsights = false
                        showInsightsPaywall = true
                    }
                }
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 28)

            // Upcoming Bill section
            upcomingBillSection
                .padding(.bottom, 32)
        }
    }

    // MARK: - Chart Data Builder

    /// Builds chart segments from current subscriptions for the donut chart.
    /// Each subscription becomes a segment proportional to its monthly spend.
    private func buildChartItems() -> [LogoDonutItem] {
        let subscriptions = viewModel.allSubscriptions

        return subscriptions.map { sub in
            let monthlyValue: Double
            switch sub.billingCycle {
            case .weekly:
                monthlyValue = sub.price * 4.33
            case .monthly:
                monthlyValue = sub.price
            case .quarterly:
                monthlyValue = sub.price / 3
            case .yearly:
                monthlyValue = sub.price / 12
            case .unknown:
                monthlyValue = sub.price
            }

            let colorIndex = viewModel.colorIndex(for: sub.id)
            return LogoDonutItem(
                id: sub.id,
                name: sub.name,
                value: monthlyValue,
                color: SubscriptionCardColors.color(for: colorIndex),
                logoName: subscriptionLogoImage(for: sub)
            )
        }
    }

    // MARK: - Greeting Row

    private var greetingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { showSettings = true }) {
                    profileAvatar
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Text("Hello,")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("", text: $userName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .focused($isNameFocused)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit { isNameFocused = false }
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .onChange(of: userName) { newValue in
                                let sanitized = sanitizeName(newValue)
                                if sanitized != newValue {
                                    userName = sanitized
                                }
                            }

                        Rectangle()
                            .fill(Color.white.opacity(isNameFocused ? 0.8 : 0.35))
                            .frame(height: 1)
                    }
                }

                Button(action: { isNameFocused = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Spacer()

                // Bell icon with notification badge
                Button(action: { showNotifications = true }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: 44, height: 44)

                        Image(systemName: "bell")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))

                        // Unread badge
                        if notificationViewModel.hasUnreadNotifications {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 18, height: 18)

                                Text(notificationViewModel.unreadCount > 9 ? "9+" : "\(notificationViewModel.unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 14, y: -14)
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showNotifications) {
                    NotificationsView(viewModel: notificationViewModel)
                }
            }

            if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !UserDefaults.standard.bool(forKey: hasSeenNameCalloutKey) {
                namePromptCallout
                    .padding(.leading, 60)
            }
        }
        .onChange(of: userName) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                UserDefaults.standard.set(true, forKey: hasSeenNameCalloutKey)
            }
        }
    }

    private var namePromptCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What should we call you?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 8)
                .offset(x: 18, y: -4),
            alignment: .topLeading
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            if let profileImageData,
               let uiImage = UIImage(data: profileImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .overlay(
            Circle()
                .fill(Color.black.opacity(0.55))
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                )
                .offset(x: 6, y: 6),
            alignment: .bottomTrailing
        )
    }

    private func loadProfile() {
        let defaults = UserDefaults.standard
        if let storedName = defaults.string(forKey: profileNameKey), !storedName.isEmpty {
            userName = sanitizeName(storedName)
        }
        if let storedImageData = defaults.data(forKey: profileImageKey) {
            profileImageData = storedImageData
        }
    }

    /// Sanitizes name input to only allow letters and spaces.
    /// Prevents injection attacks and invalid characters.
    private func sanitizeName(_ input: String) -> String {
        // Only allow letters (including accented) and spaces
        let allowedCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: " "))
        let filtered = input.unicodeScalars.filter { allowedCharacters.contains($0) }
        var result = String(String.UnicodeScalarView(filtered))

        // Collapse multiple spaces into one
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Limit length to prevent buffer issues (max 50 characters)
        if result.count > 50 {
            result = String(result.prefix(50))
        }

        return result
    }

    // MARK: - Upcoming Bill Section

    private var upcomingBillSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Upcoming Bill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                viewAllButton(lightStyle: false)
            }
            .padding(.horizontal, horizontalPadding)

            // Horizontal scroll cards
            upcomingBillsScroll
        }
    }

    private var upcomingBillsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(displayUpcomingBills.enumerated()), id: \.element.displayId) { index, bill in
                    UpcomingBillCardView(
                        subscription: bill,
                        backgroundColor: upcomingCardColor(for: index, bill: bill),
                        daysLeft: bill.daysUntilNextBilling ?? 12,
                        logoImage: subscriptionLogoImage(for: bill)
                    )
                    .onTapGesture {
                        if let original = bill.originalSubscription {
                            selectedSubscription = original
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.trailing, 40)
        }
    }

    private func upcomingCardColor(for index: Int, bill: SubscriptionDisplayWrapper) -> Color {
        // First card is featured (dark glass)
        if index == 0 {
            return SubscriptionCardColors.glassBase
        }
        // Rest match their subscription card color using persistent color index
        let colorIndex = viewModel.colorIndex(for: bill.displayId)
        return SubscriptionCardColors.color(for: colorIndex)
    }

    // MARK: - Mint Section

    private var mintSection: some View {
        VStack(spacing: 0) {
            // Subscriptions content with mint background
            subscriptionsContent
        }
        .background(darkBackground)
    }

    private var subscriptionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Subscriptions")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    addButton
                }

                Text("Subscribe multiple platforms\nonly in one place.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(2)
            }
            .padding(.horizontal, horizontalPadding)

            // Subscription cards - stacked design
            subscriptionCardsList
                .padding(.bottom, 160)
        }
        .padding(.top, 24)
    }

    private var addButton: some View {
        Button(action: { showAddSubscription = true }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subscriptionCardsList: some View {
        let subscriptions = displaySubscriptions
        let cardHeight: CGFloat = 120
        let visiblePortion: CGFloat = 106

        // Calculate drag state values
        let isDragging = dragState.isDragging
        let draggedIndex = dragState.draggedIndex
        let targetIndex: Int = {
            guard let draggedIdx = draggedIndex else { return 0 }
            return calculateTargetIndex(from: draggedIdx, translation: dragState.translation, visiblePortion: visiblePortion)
        }()

        return ZStack(alignment: .top) {
            ForEach(Array(subscriptions.enumerated()), id: \.element.displayId) { index, subscription in
                let isBeingDragged = draggedIndex == index
                let dynamicIsLastCard = calculateIsLastCard(
                    index: index,
                    totalCount: subscriptions.count,
                    draggedIndex: draggedIndex,
                    targetIndex: targetIndex,
                    isDragging: isDragging
                )

                // Calculate offset for this card
                let dragOffset: CGFloat = {
                    if isBeingDragged {
                        return CGFloat(index) * visiblePortion + dragState.translation
                    } else {
                        let animatedOffset = calculateCardOffset(
                            for: index,
                            draggedIndex: draggedIndex ?? 0,
                            targetIndex: targetIndex,
                            isDragging: isDragging,
                            visiblePortion: visiblePortion
                        )
                        return CGFloat(index) * visiblePortion + animatedOffset
                    }
                }()

                SubscriptionListCardView(
                    subscription: subscription,
                    backgroundColor: subscriptionCardColor(for: subscription.displayId),
                    logoImage: subscriptionLogoImage(for: subscription),
                    isLastCard: dynamicIsLastCard,
                    onTap: {
                        // Disable tap during drag
                        guard !isDragging else { return }
                        if let original = subscription.originalSubscription {
                            selectedSubscription = original
                        }
                    }
                )
                .padding(.horizontal, 12)
                .offset(y: dragOffset)
                .scaleEffect(isBeingDragged ? 1.05 : 1.0)
                .shadow(
                    color: Color.black.opacity(isBeingDragged ? 0.35 : 0.2),
                    radius: isBeingDragged ? 20 : 12,
                    x: 0,
                    y: isBeingDragged ? 10 : 5
                )
                .zIndex(isBeingDragged ? 1000 : Double(index))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: dragOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isBeingDragged)
                .simultaneousGesture(reorderGesture(for: index))
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: CGFloat(max(0, subscriptions.count - 1)) * visiblePortion + cardHeight,
            alignment: .top
        )
    }

    private func subscriptionLogoImage(for subscription: Subscription) -> String? {
        SubscriptionLogoResolver.assetName(for: subscription)
    }

    private func subscriptionLogoImage(for subscription: SubscriptionDisplayWrapper) -> String? {
        if let original = subscription.originalSubscription {
            return SubscriptionLogoResolver.assetName(for: original)
        }
        return SubscriptionLogoResolver.assetName(for: subscription.displayName)
    }

    private func subscriptionCardColor(for subscriptionId: UUID) -> Color {
        let colorIndex = viewModel.colorIndex(for: subscriptionId)
        return SubscriptionCardColors.color(for: colorIndex)
    }

    private func cardColorForSubscription(_ subscription: Subscription) -> Color {
        let colorIndex = viewModel.colorIndex(for: subscription.id)
        return SubscriptionCardColors.color(for: colorIndex)
    }

    // MARK: - View All Button

    private func viewAllButton(lightStyle: Bool) -> some View {
        Button(action: { showAllUpcomingBills = true }) {
            Text("View All")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(lightStyle ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(
                            lightStyle ? Color.black.opacity(0.15) : Color.white.opacity(0.25),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Display Data (Uses ViewModel data or mock for preview)

    private var displayBalance: Double {
        viewModel.totalMonthlyBalance
    }

    /// Returns real subscriptions from ViewModel
    private var displaySubscriptions: [SubscriptionDisplayWrapper] {
        return viewModel.allSubscriptions.map { SubscriptionDisplayWrapper(subscription: $0) }
    }

    /// Returns real upcoming bills from ViewModel
    private var displayUpcomingBills: [SubscriptionDisplayWrapper] {
        return viewModel.subscriptions.prefix(5).map { SubscriptionDisplayWrapper(subscription: $0) }
    }

    // MARK: - Mock Data for Preview

    private var mockSubscriptions: [SubscriptionDisplayWrapper] {
        [
            SubscriptionDisplayWrapper(name: "Apple TV", price: 18.00, icon: "apple.logo", daysLeft: 12),
            SubscriptionDisplayWrapper(name: "Netflix", price: 18.00, icon: "play.rectangle.fill", daysLeft: 14),
            SubscriptionDisplayWrapper(name: "Spotify", price: 18.00, icon: "music.note", daysLeft: 12),
            SubscriptionDisplayWrapper(name: "YouTube", price: 12.00, icon: "play.circle.fill", daysLeft: 20)
        ]
    }

    private var mockUpcomingBills: [SubscriptionDisplayWrapper] {
        [
            SubscriptionDisplayWrapper(name: "Spotify", price: 18.00, icon: "music.note", daysLeft: 12),
            SubscriptionDisplayWrapper(name: "Netflix", price: 21.00, icon: "play.rectangle.fill", daysLeft: 14),
            SubscriptionDisplayWrapper(name: "Apple TV", price: 12.00, icon: "apple.logo", daysLeft: 12)
        ]
    }

    // MARK: - Drag Reorder Gesture

    private func reorderGesture(for index: Int) -> some Gesture {
        let longPress = LongPressGesture(minimumDuration: 0.35, maximumDistance: 20)
            .onEnded { _ in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }

        let drag = DragGesture(minimumDistance: 4)
            .onEnded { value in
                let visiblePortion: CGFloat = 106
                let targetIndex = calculateTargetIndex(from: index, translation: value.translation.height, visiblePortion: visiblePortion)
                if targetIndex != index {
                    viewModel.moveSubscription(from: index, to: targetIndex)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }

        return longPress.sequenced(before: drag)
            .updating($dragState) { value, state, _ in
                switch value {
                case .first(true):
                    state = .pressing(index: index)
                case .second(true, let drag):
                    state = .dragging(index: index, translation: drag?.translation.height ?? 0)
                default:
                    state = .inactive
                }
            }
    }

    // MARK: - Drag Helper Methods

    /// Calculate the target index based on drag translation
    private func calculateTargetIndex(from sourceIndex: Int, translation: CGFloat, visiblePortion: CGFloat) -> Int {
        let subscriptions = displaySubscriptions
        let offset = Int(round(translation / visiblePortion))
        let targetIndex = sourceIndex + offset
        return max(0, min(subscriptions.count - 1, targetIndex))
    }

    /// Calculate the offset for a card during drag operations
    private func calculateCardOffset(
        for index: Int,
        draggedIndex: Int,
        targetIndex: Int,
        isDragging: Bool,
        visiblePortion: CGFloat
    ) -> CGFloat {
        guard isDragging, index != draggedIndex else { return 0 }

        if draggedIndex < targetIndex {
            // Dragging down: cards between source and target shift up
            if index > draggedIndex && index <= targetIndex {
                return -visiblePortion
            }
        } else if draggedIndex > targetIndex {
            // Dragging up: cards between target and source shift down
            if index >= targetIndex && index < draggedIndex {
                return visiblePortion
            }
        }
        return 0
    }

    /// Determine which card should have last-card styling during drag
    private func calculateIsLastCard(
        index: Int,
        totalCount: Int,
        draggedIndex: Int?,
        targetIndex: Int,
        isDragging: Bool
    ) -> Bool {
        guard totalCount > 0 else { return false }
        let lastIndex = totalCount - 1

        guard isDragging, let draggedIndex = draggedIndex else {
            return index == lastIndex
        }

        // Calculate effective index for each card during drag
        if index == draggedIndex {
            // The dragged card's effective position is the target
            return targetIndex == lastIndex
        }

        // Calculate how this card's position is affected
        var effectiveIndex = index
        if draggedIndex < targetIndex {
            if index > draggedIndex && index <= targetIndex {
                effectiveIndex = index - 1
            }
        } else if draggedIndex > targetIndex {
            if index >= targetIndex && index < draggedIndex {
                effectiveIndex = index + 1
            }
        }

        return effectiveIndex == lastIndex
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Subscription Display Wrapper

/// Wrapper to adapt Subscription model to SubscriptionCardDisplayable
struct SubscriptionDisplayWrapper: SubscriptionCardDisplayable {
    let id: UUID
    let name: String
    let price: Double
    let icon: String
    let daysLeft: Int?
    let originalSubscription: Subscription?

    init(subscription: Subscription) {
        self.id = subscription.id
        self.name = subscription.name
        self.price = subscription.price
        self.icon = "creditcard.fill" // Default icon
        self.daysLeft = subscription.daysUntilNextBilling
        self.originalSubscription = subscription
    }

    init(name: String, price: Double, icon: String, daysLeft: Int?) {
        let subId = UUID()
        self.id = subId
        self.name = name
        self.price = price
        self.icon = icon
        self.daysLeft = daysLeft
        self.originalSubscription = Subscription(
            id: subId,
            merchantId: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: name,
            price: price,
            billingCycle: .monthly,
            confidence: .high,
            nextBillingDate: daysLeft != nil ? Calendar.current.date(byAdding: .day, value: daysLeft!, to: Date()) : nil,
            lastChargeDate: nil,
            emailCount: 0,
            senderEmail: "",
            detectedAt: Date(),
            detectionSource: .manual
        )
    }

    var displayId: UUID { id }
    var displayName: String { name }
    var displayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    var displayPriceValue: Double { price }
    var displayBillingCycle: String { "Monthly" }
    var displayIconName: String { icon }
    var displayIconColor: Color { .black }
    var displayBackgroundColor: Color { .white }
    var daysUntilNextBilling: Int? { daysLeft }
}

// MARK: - Preview

#Preview {
    HomeView()
}
