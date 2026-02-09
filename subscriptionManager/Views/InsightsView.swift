//
//  InsightsView.swift
//  subscriptionManager
//
//  Created by Claude on 1/20/26.
//

import SwiftUI
import UIKit

struct InsightsView: View {
    @StateObject private var viewModel: InsightsViewModel

    @State private var sharePayload: SharePayload?
    @State private var showExportError = false
    @State private var selectedMonth: Date = Date()

    // Store subscriptions to detect changes
    private let subscriptions: [Subscription]

    // Color indices mapping (subscription ID -> color index)
    private let colorIndices: [UUID: Int]

    // MARK: - Theme Constants

    private let backgroundColor = Color(red: 0.07, green: 0.07, blue: 0.08)
    private let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.13)
    private let mintColor = Color(red: 0.78, green: 0.93, blue: 0.87)

    // MARK: - Initialization

    init(subscriptions: [Subscription], colorIndices: [UUID: Int] = [:]) {
        self.subscriptions = subscriptions
        self.colorIndices = colorIndices
        _viewModel = StateObject(wrappedValue: InsightsViewModel(subscriptions: subscriptions))
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Monthly spending overview with donut chart
                    spendingOverviewCard
                        .padding(.top, 8)

                    // Category breakdown and subscriptions list
                    if !viewModel.categoryBreakdown.isEmpty {
                        subscriptionsListSection

                        // Only show category breakdown if meaningful (more than 1 category, or not just "Other")
                        if shouldShowCategoryBreakdown {
                            categoryBreakdownSection
                        } else {
                            billingCycleSection
                        }

                        summarySection
                    } else if subscriptions.isEmpty {
                        // Only show generic empty state when user has no subscriptions at all
                        emptyStateView
                    }

                    // Export button (hidden when no data for selected month)
                    if !viewModel.categoryBreakdown.isEmpty {
                        exportButton
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't create the export files. Please try again.")
        }
        .onAppear {
            AnalyticsService.screen("insights")
            AnalyticsService.event("insights_view")
            // Ensure data is current on appear
            viewModel.updateSubscriptions(subscriptions)
            viewModel.updateSelectedMonth(selectedMonth)
        }
        .onChange(of: subscriptions) { newSubscriptions in
            viewModel.updateSubscriptions(newSubscriptions)
        }
        .onChange(of: selectedMonth) { newMonth in
            viewModel.updateSelectedMonth(newMonth)
        }
    }

    // MARK: - Spending Overview Card

    private var spendingOverviewCard: some View {
        VStack(spacing: 20) {
            // Month selector with navigation - top left
            HStack {
                monthSelector
                Spacer()
            }

            if viewModel.categoryBreakdown.isEmpty {
                // Empty state for months with no tracked subscriptions
                VStack(spacing: 12) {
                    Text("$0.00")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("No tracked subscriptions this month")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                // Larger donut chart with thicker ring
                ZStack {
                    LogoDonutChartView(
                        items: categoryRingItems,
                        lineWidth: 48,  // 20% thicker
                        size: 240,      // Larger chart
                        showLogos: false
                    )

                    chartCenterLabel
                }
                .frame(maxWidth: .infinity)

                legendGrid
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var monthSelector: some View {
        HStack(spacing: 4) {
            // Previous month button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
            }

            // Month label
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Text(selectedMonthLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 80)
            }

            // Next month button (disabled if current month)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isCurrentMonth ? .white.opacity(0.2) : .white.opacity(0.6))
                    .frame(width: 28, height: 28)
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }

    private var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var chartCenterLabel: some View {
        VStack(spacing: 4) {
            Text("Total")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text(viewModel.formattedTotalMonthly)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 120, height: 120)
        .background(
            Circle()
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var legendGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 24),
            GridItem(.flexible(), spacing: 24)
        ]

        // Use individual subscriptions for legend (matching chart segments)
        let subscriptions = viewModel.allSubscriptionsSortedBySpend

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(subscriptions, id: \.id) { subscription in
                HStack(spacing: 8) {
                    Circle()
                        .fill(colorForSubscription(subscription.id))
                        .frame(width: 8, height: 8)

                    Text(subscription.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Subscriptions List Section

    private var subscriptionsListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with date and total
            HStack {
                Text(formattedCurrentDate)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Text(viewModel.formattedTotalMonthly)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Subscriptions list
            VStack(spacing: 0) {
                ForEach(Array(viewModel.allSubscriptionsSortedBySpend.enumerated()), id: \.element.id) { index, subscription in
                    subscriptionRow(subscription: subscription)

                    if index < viewModel.allSubscriptionsSortedBySpend.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 60)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private func subscriptionRow(subscription: Subscription) -> some View {
        let logoName = SubscriptionLogoResolver.assetName(for: subscription)
        let monthlyAmount = viewModel.monthlyEquivalent(for: subscription)
        let category = viewModel.category(for: subscription)
        let cornerRadius: CGFloat = 12
        let logoSize: CGFloat = 48

        return HStack(spacing: 14) {
            // Subscription logo - rounded square style
            if let logoName = logoName, UIImage(named: logoName) != nil {
                Image(logoName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white)
                    Text(String(subscription.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gray)
                }
                .frame(width: logoSize, height: logoSize)
            }

            // Subscription name and category
            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(subscription.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Monthly amount
            Text(formatCurrency(monthlyAmount))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    // MARK: - Category Breakdown Section

    /// Only show category breakdown if there are multiple categories or if not all are "Other"
    private var shouldShowCategoryBreakdown: Bool {
        let categories = viewModel.categoryBreakdown
        if categories.count > 1 { return true }
        if categories.count == 1 && categories[0].category != .other { return true }
        return false
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary by Category")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.categoryBreakdown.enumerated()), id: \.element.id) { index, spending in
                    categoryRow(spending: spending, color: ChartColors.color(for: index))

                    if index < viewModel.categoryBreakdown.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Billing Cycle Section

    private var billingCycleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Billing Breakdown")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                ForEach(viewModel.billingCycleBreakdown, id: \.cycle) { item in
                    billingCycleRow(cycle: item.cycle, count: item.count, total: item.total)

                    if item.cycle != viewModel.billingCycleBreakdown.last?.cycle {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    private func billingCycleRow(cycle: BillingCycle, count: Int, total: Double) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cycleColor(for: cycle).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: cycleIcon(for: cycle))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(cycleColor(for: cycle))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cycle.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(count) subscription\(count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Text(formatCurrency(total))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func cycleIcon(for cycle: BillingCycle) -> String {
        switch cycle {
        case .weekly: return "clock.arrow.circlepath"
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.clock"
        case .yearly: return "calendar.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    private func cycleColor(for cycle: BillingCycle) -> Color {
        switch cycle {
        case .weekly: return Color(red: 0.95, green: 0.6, blue: 0.4)
        case .monthly: return Color(red: 0.4, green: 0.7, blue: 0.95)
        case .quarterly: return Color(red: 0.7, green: 0.5, blue: 0.9)
        case .yearly: return Color(red: 0.5, green: 0.85, blue: 0.6)
        case .unknown: return Color.gray
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Insights")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // Top row - Yearly projection (full width, highlighted)
            yearlyProjectionCard

            // Bottom row - 3 smaller stats
            HStack(spacing: 10) {
                statCard(
                    icon: "calendar",
                    title: "Daily",
                    value: formatCurrency(viewModel.dailyCost),
                    subtitle: "per day"
                )

                if let topSub = viewModel.topSubscription {
                    statCard(
                        icon: "arrow.up.circle.fill",
                        title: "Highest",
                        value: topSub.name,
                        subtitle: formatCurrency(viewModel.topSubscriptionMonthly) + "/mo"
                    )
                } else {
                    statCard(
                        icon: "arrow.up.circle.fill",
                        title: "Highest",
                        value: "-",
                        subtitle: "No subscriptions"
                    )
                }

                if let nextSub = viewModel.nextBillingSubscription,
                   let days = viewModel.daysUntilNextBilling {
                    statCard(
                        icon: "clock.fill",
                        title: "Next Bill",
                        value: days == 0 ? "Today" : "\(days)d",
                        subtitle: nextSub.name
                    )
                } else {
                    statCard(
                        icon: "clock.fill",
                        title: "Next Bill",
                        value: "-",
                        subtitle: "No upcoming"
                    )
                }
            }
        }
    }

    private var yearlyProjectionCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(mintColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(mintColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Yearly Projection")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(formatCurrency(viewModel.yearlyProjection))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("\(viewModel.subscriptionCount) active")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(mintColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func statCard(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func categoryRow(spending: CategorySpending, color: Color) -> some View {
        let logoName = topLogoName(for: spending)
        let cornerRadius: CGFloat = 12
        let logoSize: CGFloat = 48

        return HStack(spacing: 14) {
            // Subscription logo or category icon fallback - rounded square style
            if let logoName = logoName, UIImage(named: logoName) != nil {
                Image(logoName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white)
                    Image(systemName: spending.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                .frame(width: logoSize, height: logoSize)
            }

            // Category name and count
            VStack(alignment: .leading, spacing: 4) {
                Text(spending.category.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(spending.subscriptionCount) subscription\(spending.subscriptionCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Monthly total
            Text(spending.formattedTotal)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No subscriptions to analyze")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Text("Add some subscriptions to see your spending insights.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            AnalyticsService.event("insights_export_tapped")
            if let urls = viewModel.exportForShare(), !urls.isEmpty {
                sharePayload = SharePayload(items: urls)
            } else {
                showExportError = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))

                Text("Export to CSV")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(mintColor)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Helpers

    private var categoryRingItems: [LogoDonutItem] {
        // Use individual subscriptions (like Home chart) instead of categories
        let subscriptions = viewModel.allSubscriptionsSortedBySpend
        guard !subscriptions.isEmpty else { return [] }

        return subscriptions.map { subscription in
            let monthlyValue = viewModel.monthlyEquivalent(for: subscription)
            let logoName = SubscriptionLogoResolver.assetName(for: subscription)

            return LogoDonutItem(
                id: subscription.id,
                name: subscription.name,
                value: monthlyValue,
                color: colorForSubscription(subscription.id),
                logoName: logoName
            )
        }
    }

    /// Get the color for a subscription using passed color indices (matches HomeView)
    private func colorForSubscription(_ id: UUID) -> Color {
        let index = colorIndices[id] ?? 0
        return SubscriptionCardColors.color(for: index)
    }

    private func topLogoName(for spending: CategorySpending) -> String? {
        let topSubscription = spending.subscriptions.max {
            viewModel.monthlyEquivalent(for: $0) < viewModel.monthlyEquivalent(for: $1)
        }
        guard let subscription = topSubscription else { return nil }
        return SubscriptionLogoResolver.assetName(for: subscription)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController,
           let window = UIApplication.shared.connectedScenes
               .compactMap({ $0 as? UIWindowScene })
               .flatMap({ $0.windows })
               .first(where: { $0.isKeyWindow }) {
            popover.sourceView = window
            popover.sourceRect = CGRect(
                x: window.bounds.midX,
                y: window.bounds.midY,
                width: 1,
                height: 1
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - Preview

#Preview {
    InsightsView(subscriptions: [
        Subscription(
            merchantId: "netflix",
            name: "Netflix",
            price: 15.99,
            billingCycle: .monthly,
            senderEmail: "billing@netflix.com"
        ),
        Subscription(
            merchantId: "spotify",
            name: "Spotify",
            price: 9.99,
            billingCycle: .monthly,
            senderEmail: "billing@spotify.com"
        )
    ])
}
