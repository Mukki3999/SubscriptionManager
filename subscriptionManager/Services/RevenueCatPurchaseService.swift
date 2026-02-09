//
//  RevenueCatPurchaseService.swift
//  subscriptionManager
//
//  Created by Claude on 1/29/26.
//

import Foundation
import RevenueCat
import StoreKit

// MARK: - Paywall Variant

/// Represents which paywall UI variant to show for A/B testing
enum PaywallVariant: String {
    case custom = "custom"
    case revenueCat = "revenuecat"

    var analyticsValue: String { rawValue }
}

// MARK: - RevenueCat Purchase Service

/// Service for handling purchases via RevenueCat SDK with A/B testing support
@MainActor
final class RevenueCatPurchaseService: NSObject, ObservableObject {

    static let shared = RevenueCatPurchaseService()

    // MARK: - Published Properties

    @Published private(set) var offerings: Offerings?
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var hasActiveSubscription: Bool = false
    @Published private(set) var subscriptionExpirationDate: Date?
    @Published private(set) var isLoading: Bool = false

    /// The determined paywall variant from A/B test. Nil until offerings are loaded.
    @Published private(set) var currentPaywallVariant: PaywallVariant?

    // MARK: - Computed Properties

    /// Whether offerings have been loaded and variant is determined
    var isReady: Bool {
        currentOffering != nil && currentPaywallVariant != nil
    }

    /// Whether to show RevenueCat's paywall UI based on A/B test assignment
    /// Returns false if variant hasn't been determined yet
    var shouldShowRevenueCatPaywall: Bool {
        currentPaywallVariant == .revenueCat
    }

    /// Get available packages from current offering
    var availablePackages: [Package] {
        currentOffering?.availablePackages ?? []
    }

    /// Get the monthly package
    var monthlyPackage: Package? {
        currentOffering?.monthly ?? availablePackages.first { $0.packageType == .monthly }
    }

    /// Get the annual package
    var annualPackage: Package? {
        currentOffering?.annual ?? availablePackages.first { $0.packageType == .annual }
    }

    // MARK: - Private Properties

    private var isConfigured = false
    private var loadOfferingsTask: Task<Void, Never>?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Configure RevenueCat SDK - call this once at app launch
    func configure() {
        guard !isConfigured else { return }

        let apiKey = RevenueCatConfig.apiKey
        guard !apiKey.isEmpty else {
            print("RevenueCatPurchaseService: API key not configured, skipping initialization")
            return
        }

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self

        isConfigured = true
        print("RevenueCatPurchaseService: Configured successfully")

        // Load offerings and check subscription status
        Task {
            await loadOfferings()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Public Methods

    /// Load available offerings from RevenueCat.
    /// If a load is already in progress, callers await the same task instead of bailing out.
    func loadOfferings() async {
        guard isConfigured else {
            print("RevenueCatPurchaseService: Not configured, skipping offerings load")
            return
        }

        // If already loading, await the in-progress task
        if let existingTask = loadOfferingsTask {
            await existingTask.value
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            do {
                let offerings = try await Purchases.shared.offerings()
                self.offerings = offerings
                self.currentOffering = offerings.current
                determinePaywallVariant()
                print("RevenueCatPurchaseService: Loaded offerings - current: \(offerings.current?.identifier ?? "none")")
            } catch {
                print("RevenueCatPurchaseService: Failed to load offerings - \(error.localizedDescription)")
            }
            isLoading = false
            loadOfferingsTask = nil
        }
        loadOfferingsTask = task
        await task.value
    }

    /// Purchase a package
    func purchase(package: Package) async throws {
        guard isConfigured else {
            throw PurchaseError.unknownError
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if !result.userCancelled {
                // Update subscription status after successful purchase
                await checkSubscriptionStatus()
                print("RevenueCatPurchaseService: Purchase successful for \(package.identifier)")
            } else {
                throw PurchaseError.purchaseCancelled
            }
        } catch let error as ErrorCode {
            throw mapRevenueCatError(error)
        } catch {
            if let purchaseError = error as? PurchaseError {
                throw purchaseError
            }
            throw PurchaseError.purchaseFailed
        }
    }

    /// Purchase by product identifier (for compatibility)
    func purchase(productID: String) async throws {
        guard let package = availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) else {
            throw PurchaseError.productNotFound
        }
        try await purchase(package: package)
    }

    /// Restore previous purchases
    func restorePurchases() async throws {
        guard isConfigured else {
            throw PurchaseError.unknownError
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateSubscriptionStatus(from: customerInfo)
            print("RevenueCatPurchaseService: Purchases restored")
        } catch {
            print("RevenueCatPurchaseService: Restore failed - \(error.localizedDescription)")
            throw PurchaseError.unknownError
        }
    }

    /// Check current subscription status
    func checkSubscriptionStatus() async {
        guard isConfigured else { return }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateSubscriptionStatus(from: customerInfo)
        } catch {
            print("RevenueCatPurchaseService: Failed to get customer info - \(error.localizedDescription)")
        }
    }

    /// Get the monthly product (for compatibility with existing code)
    func getMonthlyProduct() -> StoreProduct? {
        monthlyPackage?.storeProduct
    }

    /// Get the annual product (for compatibility with existing code)
    func getAnnualProduct() -> StoreProduct? {
        annualPackage?.storeProduct
    }

    // MARK: - Private Methods

    /// Determine which paywall variant to show based on offering
    private func determinePaywallVariant() {
        guard let offering = currentOffering else {
            // No offering available - default to RevenueCat paywall
            // This handles edge cases where offerings fail to load
            currentPaywallVariant = .revenueCat
            print("RevenueCatPurchaseService: No offering available, defaulting to RevenueCat paywall")
            return
        }

        // RevenueCat Experiments assigns users to different offerings
        // Based on your experiment setup:
        // - "custom_paywall" offering → show custom Swift paywall (Variant A)
        // - "default" offering → show RevenueCat paywall (Variant B)
        if offering.identifier == RevenueCatConfig.OfferingID.customPaywall {
            currentPaywallVariant = .custom
        } else {
            currentPaywallVariant = .revenueCat
        }

        print("RevenueCatPurchaseService: Paywall variant = \(currentPaywallVariant?.rawValue ?? "nil") (offering: \(offering.identifier))")
    }

    /// Update subscription status from customer info
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[RevenueCatConfig.entitlementID]
        let isActive = entitlement?.isActive == true

        hasActiveSubscription = isActive
        subscriptionExpirationDate = entitlement?.expirationDate

        // Sync with TierManager
        TierManager.shared.updateTier(isActive ? .pro : .free)

        // Update analytics user property
        AnalyticsService.setUserProperty(isActive ? "pro" : "free", for: "subscription_status")

        print("RevenueCatPurchaseService: Subscription status = \(isActive ? "active" : "inactive")")
    }

    /// Map RevenueCat error to our PurchaseError
    private func mapRevenueCatError(_ error: ErrorCode) -> PurchaseError {
        switch error {
        case .purchaseCancelledError:
            return .purchaseCancelled
        case .productNotAvailableForPurchaseError,
             .productAlreadyPurchasedError:
            return .productNotFound
        case .purchaseNotAllowedError,
             .purchaseInvalidError:
            return .purchaseFailed
        case .receiptAlreadyInUseError:
            return .verificationFailed
        default:
            return .unknownError
        }
    }
}

// MARK: - PurchasesDelegate

extension RevenueCatPurchaseService: PurchasesDelegate {

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            updateSubscriptionStatus(from: customerInfo)
        }
    }
}

// MARK: - StoreProduct Extensions

extension StoreProduct {
    /// Formatted price with period
    var formattedPriceWithPeriod: String {
        if let period = subscriptionPeriod {
            let periodText: String
            switch period.unit {
            case .month:
                periodText = period.value == 1 ? "/mo" : "/\(period.value)mo"
            case .year:
                periodText = period.value == 1 ? "/yr" : "/\(period.value)yr"
            case .week:
                periodText = period.value == 1 ? "/wk" : "/\(period.value)wk"
            case .day:
                periodText = period.value == 1 ? "/day" : "/\(period.value)day"
            @unknown default:
                periodText = ""
            }
            return "\(localizedPriceString)\(periodText)"
        }
        return localizedPriceString
    }

    /// Monthly equivalent price for annual subscriptions
    var monthlyEquivalent: String? {
        guard let period = subscriptionPeriod, period.unit == .year else { return nil }

        let monthlyPrice = price / Decimal(12 * period.value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceFormatter?.locale ?? .current
        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    /// Check if this product offers a free trial
    var hasFreeTrial: Bool {
        introductoryDiscount?.paymentMode == .freeTrial
    }

    /// Free trial duration description
    var freeTrialDuration: String? {
        guard let intro = introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }

        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day:
            return "\(period.value)-day free trial"
        case .week:
            return "\(period.value)-week free trial"
        case .month:
            return "\(period.value)-month free trial"
        case .year:
            return "\(period.value)-year free trial"
        @unknown default:
            return "Free trial"
        }
    }
}

// MARK: - Package Extensions

extension Package {
    /// Convenience accessor for underlying StoreProduct
    var product: StoreProduct {
        storeProduct
    }
}
