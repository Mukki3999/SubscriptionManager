//
//  PurchaseService.swift
//  subscriptionManager
//
//  Created by Claude on 1/19/26.
//

import Foundation
import StoreKit

// MARK: - Purchase Error

enum PurchaseError: LocalizedError {
    case productNotFound
    case purchaseFailed
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found. Please try again later."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .purchasePending:
            return "Purchase is pending approval."
        case .verificationFailed:
            return "Could not verify purchase. Please contact support."
        case .unknownError:
            return "An unknown error occurred. Please try again."
        }
    }
}

// MARK: - Purchase Service

/// Service for handling StoreKit 2 in-app purchases
@MainActor
final class PurchaseService: ObservableObject {

    static let shared = PurchaseService()

    // MARK: - Published Properties

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasActiveSubscription: Bool = false
    @Published private(set) var subscriptionExpirationDate: Date?

    // MARK: - Private Properties

    private var transactionListener: Task<Void, Error>?
    private let productIDs = PremiumProduct.allCases.map { $0.rawValue }

    // MARK: - Initialization

    private init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()

        // Load products and check subscription status on init
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public Methods

    /// Load available products from the App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
            print("PurchaseService: Loaded \(products.count) products")
        } catch {
            print("PurchaseService: Failed to load products - \(error.localizedDescription)")
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Check if the transaction is verified
            let transaction = try checkVerified(verification)

            // Update the customer's purchases
            await updatePurchasedProducts()

            // Always finish a transaction
            await transaction.finish()

            print("PurchaseService: Purchase successful for \(product.id)")

        case .userCancelled:
            throw PurchaseError.purchaseCancelled

        case .pending:
            throw PurchaseError.purchasePending

        @unknown default:
            throw PurchaseError.unknownError
        }
    }

    /// Purchase by product identifier
    func purchase(productID: String) async throws {
        guard let product = products.first(where: { $0.id == productID }) else {
            throw PurchaseError.productNotFound
        }
        try await purchase(product)
    }

    /// Restore previous purchases
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        // Sync with the App Store
        try await AppStore.sync()

        // Update purchased products
        await updatePurchasedProducts()

        print("PurchaseService: Purchases restored")
    }

    /// Check current subscription status
    func checkSubscriptionStatus() async {
        await updatePurchasedProducts()

        // Check for active subscription
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIDs.contains(transaction.productID) {
                    hasActiveSubscription = true
                    subscriptionExpirationDate = transaction.expirationDate
                    TierManager.shared.updateTier(.pro)
                    return
                }
            }
        }

        // No active subscription found
        hasActiveSubscription = false
        subscriptionExpirationDate = nil
        TierManager.shared.updateTier(.free)
    }

    /// Get the monthly product
    func getMonthlyProduct() -> Product? {
        products.first { $0.id == PremiumProduct.monthly.rawValue }
    }

    /// Get the annual product
    func getAnnualProduct() -> Product? {
        products.first { $0.id == PremiumProduct.annual.rawValue }
    }

    // MARK: - Private Methods

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("PurchaseService: Transaction verification failed - \(error.localizedDescription)")
                }
            }
        }
    }

    /// Verify a transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    /// Update the set of purchased product IDs
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var hasActive = false
        var expirationDate: Date?

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)

                // Check if this is one of our subscription products
                if productIDs.contains(transaction.productID) {
                    hasActive = true
                    if let expDate = transaction.expirationDate {
                        if expirationDate == nil || expDate > expirationDate! {
                            expirationDate = expDate
                        }
                    }
                }
            }
        }

        purchasedProductIDs = purchased
        hasActiveSubscription = hasActive
        subscriptionExpirationDate = expirationDate

        // Update tier manager
        TierManager.shared.updateTier(hasActive ? .pro : .free)
    }
}

// MARK: - Product Extensions

extension Product {
    /// Formatted price with period
    var formattedPriceWithPeriod: String {
        if let subscription = self.subscription {
            let period = subscription.subscriptionPeriod
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
            return "\(displayPrice)\(periodText)"
        }
        return displayPrice
    }

    /// Monthly equivalent price for annual subscriptions
    var monthlyEquivalent: String? {
        guard let subscription = self.subscription else { return nil }
        let period = subscription.subscriptionPeriod

        if period.unit == .year {
            let monthlyPrice = price / Decimal(12 * period.value)
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = priceFormatStyle.locale
            return formatter.string(from: monthlyPrice as NSDecimalNumber)
        }
        return nil
    }

    /// Check if this product offers a free trial
    var hasFreeTrial: Bool {
        subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Free trial duration description
    var freeTrialDuration: String? {
        guard let intro = subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }

        let period = intro.period
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
