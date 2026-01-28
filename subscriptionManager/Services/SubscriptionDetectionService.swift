//
//  SubscriptionDetectionService.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/14/26.
//

import Foundation

// MARK: - Scan Mode

/// Scan mode for subscription detection
enum ScanMode {
    /// Use history API to fetch only new emails since last scan (default for rescans)
    case incremental
    /// Complete rescan of all emails (first time or forced refresh)
    case full

    var displayName: String {
        switch self {
        case .incremental: return "Quick Scan"
        case .full: return "Full Scan"
        }
    }
}

// MARK: - Detection Configuration

/// Configuration for subscription detection tuning
struct DetectionConfig {
    var maxEmailsToScan: Int = 500
    var monthsToScan: Int = 12
    var minConfidenceScore: Int = 50
    var minHighConfidenceScore: Int = 70
    var useCategoryFilter: Bool = true
    var useMetadataOnlyMode: Bool = true

    static let `default` = DetectionConfig()
}

// MARK: - Keyword Scoring Rules

/// Defines scoring weights for different signal types
private enum ScoringWeight {
    static let knownMerchant = 30
    static let strongKeyword = 20
    static let mediumKeyword = 10
    static let structuralPricePattern = 15
    static let trialConversion = 18
    static let consistentPricing = 15
    static let recurringMonthly = 20
    static let recurringQuarterly = 15
    static let recurringYearly = 15
    static let recurringWeekly = 10
    static let consistencyBonus = 10
    static let multipleEmails = 5
    static let manyEmails = 5
    static let paymentProcessorMerchantFound = 25
    static let hasUnsubscribeHeader = 5
    static let antiKeywordPenalty = -25
    static let hardExclusionPenalty = -100
}

/// A sophisticated 2-pass subscription detection engine with strict filtering.
@MainActor
final class SubscriptionDetectionService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var progress: ScanProgress = .initial
    @Published private(set) var isScanning = false

    // MARK: - Dependencies

    private let gmailService: GmailAPIService
    private let merchantDB = MerchantDatabase.shared
    private let config: DetectionConfig

    // MARK: - Caching & Sync

    private let messageCache = GmailMessageCache.shared
    private let syncStateManager = GmailSyncStateManager.shared

    // MARK: - Blocklists

    /// Domains that should NEVER be flagged as subscriptions
    private let blockedDomains: Set<String> = [
        // Banks & Financial Institutions
        "bankofamerica.com", "bofa.com", "boa.com",
        "chase.com", "jpmorganchase.com",
        "wellsfargo.com", "wf.com",
        "citi.com", "citibank.com",
        "capitalone.com",
        "usbank.com",
        "pnc.com",
        "td.com", "tdbank.com",
        "schwab.com",
        "fidelity.com",
        "vanguard.com",
        "americanexpress.com", "aexp.com",
        "discover.com",
        "synchrony.com",
        "ally.com",
        "marcus.com",
        "sofi.com",
        "robinhood.com",
        "coinbase.com",
        "binance.com",

        // Social/personal email (not subscriptions)
        "gmail.com", "googlemail.com",
        "yahoo.com", "ymail.com",
        "outlook.com", "hotmail.com", "live.com",
        "icloud.com", "me.com", "mac.com",
        "aol.com",
        "protonmail.com", "proton.me",

        // Job sites / transactional
        "linkedin.com",
        "indeed.com",
        "glassdoor.com",

        // Shipping / delivery notifications
        "ups.com",
        "fedex.com",
        "usps.com",
        "dhl.com",
        "ontrac.com",
        "lasership.com",

        // E-commerce (orders, not subscriptions)
        "ebay.com",
        "etsy.com",
        "wish.com",
        "aliexpress.com",
        "alibaba.com",
        "shopify.com",
        "bigcommerce.com",

        // Insurance
        "geico.com",
        "statefarm.com",
        "progressive.com",
        "allstate.com",
        "libertymutual.com",

        // Utilities
        "pge.com",
        "sce.com",
        "coned.com",
        "nationalgrid.com",

        // Government
        "irs.gov",
        "ssa.gov",
        "dmv.gov",
        "ca.gov",
        "ny.gov"
    ]

    /// Payment processors - need special handling to extract actual merchant
    private let paymentProcessorDomains: Set<String> = [
        "paypal.com", "paypal-communication.com",
        "stripe.com",
        "squareup.com", "square.com",
        "braintreepayments.com",
        "paddle.com",
        "gumroad.com",
        "lemonsqueezy.com",
        "chargebee.com",
        "recurly.com",
        "2checkout.com",
        "fastspring.com"
    ]

    /// Domains to completely exclude (hard filter at query level)
    private let hardExcludeDomains: Set<String> = [
        "venmo.com",
        "zelle.com",
        "cashapp.com",
        "klarna.com",
        "affirm.com",
        "afterpay.com"
    ]

    /// Keywords in sender name that indicate an individual, not a business
    private let individualPatterns: [String] = [
        "publisher", "author", "editor",
        "via paypal", "sent you",
        "family", "friend",
        "personal", "private"
    ]

    // MARK: - Positive Keywords (strong subscription signals)

    private let strongSubscriptionKeywords: Set<String> = [
        // Direct subscription terms
        "subscription", "your subscription", "subscription renewal",
        "membership", "your membership", "membership renewal",
        "renewal", "auto-renewal", "will renew", "renews on",
        "automatically renews", "auto renew",
        "recurring", "recurring charge", "recurring payment",

        // Plan terms
        "monthly plan", "annual plan", "yearly plan",
        "premium", "pro plan", "plus plan", "basic plan",
        "billing cycle", "next billing date", "billing period",

        // Confirmation terms
        "subscription confirmed", "thanks for subscribing",
        "welcome to your subscription", "subscription activated",

        // Management terms (strong signal)
        "manage your subscription", "cancel your subscription",
        "update your subscription", "subscription settings"
    ]

    private let mediumSubscriptionKeywords: Set<String> = [
        "receipt", "payment receipt",
        "invoice", "payment confirmation",
        "charged", "payment processed",
        "thank you for your payment",
        "successfully charged",
        "payment successful"
    ]

    /// Trial-related keywords (indicates potential subscription)
    private let trialKeywords: Set<String> = [
        "trial ending", "trial ends", "trial expiring",
        "trial conversion", "free trial ending",
        "trial period ending", "trial will end",
        "upgrade from trial", "trial expires"
    ]

    // MARK: - Negative Keywords (NOT subscriptions)

    private let antiKeywords: Set<String> = [
        // Shipping/orders (hard exclusion)
        "shipped", "shipping", "shipment",
        "delivery", "delivered", "out for delivery",
        "tracking", "track your", "tracking number",
        "package", "parcel", "your package",

        // Bank statements (hard exclusion)
        "statement", "bank statement", "account statement",
        "statement ready", "view statement", "e-statement",
        "account summary", "account ending in",
        "direct deposit", "wire transfer",
        "account alert", "low balance", "overdraft",
        "transaction alert", "fraud alert",

        // One-time purchases
        "order shipped", "order delivered",
        "refund", "return", "refunded",
        "one-time", "one time purchase",

        // Insurance & Utilities
        "policy", "insurance", "premium due",
        "policy renewal", "coverage", "claim",
        "utility", "utility bill", "electric bill",
        "gas bill", "water bill",

        // Jobs/applications
        "application", "applied", "job alert",
        "interview", "candidate", "resume",

        // Personal transfers
        "sent you money", "paid you",
        "request", "requested money",
        "money request",

        // Ride-hailing / Trip receipts (NOT subscriptions)
        "trip with uber", "trip with lyft",
        "your ride", "ride receipt", "trip receipt",
        "your trip", "evening trip", "morning trip",
        "afternoon trip", "your uber trip", "your lyft trip",
        "trip on", "ride on", "fare",
        "popular picks", "reorder"
    ]

    /// Hard exclusion keywords - if found, immediately reject
    private let hardExclusionKeywords: Set<String> = [
        "order confirmation", "order #", "order number",
        "your order has shipped",
        "bank statement", "account statement",
        "policy renewal", "insurance premium",
        "tracking number", "track your package",
        // Ride-hailing trip receipts (hard reject)
        "trip with uber", "trip with lyft",
        "your thursday", "your friday", "your saturday",
        "your sunday", "your monday", "your tuesday", "your wednesday",
        "evening trip", "morning trip", "afternoon trip"
    ]

    /// Cancellation keywords - indicate subscription is no longer active
    private let cancellationKeywords: Set<String> = [
        "cancelled", "canceled", "subscription cancelled", "subscription canceled",
        "subscription ended", "subscription has ended",
        "membership cancelled", "membership canceled",
        "successfully cancelled", "successfully canceled",
        "cancellation confirmed", "cancellation complete",
        "final payment", "last payment",
        "subscription expired", "membership expired",
        "no longer subscribed", "unsubscribed",
        "account closed", "service terminated",
        "refund processed", "full refund"
    ]

    // MARK: - Structural Patterns (Regex)

    /// Patterns that strongly indicate subscription pricing
    private let structuralPricePatterns: [String] = [
        #"\$\d+(?:\.\d{2})?\s*/\s*(?:mo|month)"#,       // $9.99/mo or $9.99/month
        #"\$\d+(?:\.\d{2})?\s*/\s*(?:yr|year)"#,        // $99.99/yr or $99.99/year
        #"\$\d+(?:\.\d{2})?\s*per\s*month"#,            // $9.99 per month
        #"\$\d+(?:\.\d{2})?\s*per\s*year"#,             // $99.99 per year
        #"€\d+(?:,\d{2})?\s*/\s*(?:mo|month)"#,         // €9,99/mo
        #"billed\s+(?:monthly|annually|yearly)"#,       // billed monthly
        #"(?:monthly|annual|yearly)\s+(?:charge|fee)"#  // monthly charge
    ]

    /// Patterns to extract merchant name from payment processor emails
    private let merchantExtractionPatterns: [String] = [
        #"Receipt from\s+([A-Za-z0-9\s\-\.]+)"#,           // Stripe: "Receipt from Figma"
        #"Payment to\s+([A-Za-z0-9\s\-\.]+)"#,             // PayPal: "Payment to Notion"
        #"automatic payment to\s+([A-Za-z0-9\s\-\.]+)"#,   // PayPal recurring
        #"Statement descriptor:\s*([A-Za-z0-9\s\-\.]+)"#,  // Stripe descriptor
        #"Merchant:\s*([A-Za-z0-9\s\-\.]+)"#,              // Generic merchant field
        #"paid\s+([A-Za-z0-9\s\-\.]+)\s+\$"#               // "paid Spotify $9.99"
    ]

    // MARK: - Initialization

    init(gmailService: GmailAPIService = GmailAPIService(), config: DetectionConfig = .default) {
        self.gmailService = gmailService
        self.config = config
    }

    // MARK: - Public Methods

    /// Scan for subscriptions with optional incremental mode
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - mode: Scan mode (.incremental for rescan, .full for first time or forced)
    /// - Returns: DetectionResult with found subscriptions
    func scanForSubscriptions(
        accessToken: String,
        mode: ScanMode = .incremental
    ) async throws -> DetectionResult {
        let startTime = Date()
        isScanning = true
        progress = .initial

        defer { isScanning = false }

        // Determine effective scan mode
        let effectiveMode = await determineEffectiveScanMode(
            requestedMode: mode,
            accessToken: accessToken
        )

        // Pass 1: Fast metadata scan with optimized query
        progress = ScanProgress(
            phase: .fetchingMetadata,
            emailsScanned: 0,
            candidatesFound: 0,
            hasGmailAccount: true,
            storeKitPhase: .unavailable,
            transactionsScanned: 0,
            storeKitCandidatesFound: 0
        )

        let candidates: [MerchantCandidate]

        switch effectiveMode {
        case .incremental:
            candidates = try await performIncrementalScan(accessToken: accessToken)
        case .full:
            candidates = try await performFullScan(accessToken: accessToken)
        }

        // Pass 2: Detailed analysis with enhanced scoring
        progress = ScanProgress(
            phase: .analyzingCandidates,
            emailsScanned: progress.emailsScanned,
            candidatesFound: candidates.count,
            hasGmailAccount: true,
            storeKitPhase: .unavailable,
            transactionsScanned: 0,
            storeKitCandidatesFound: 0
        )

        let subscriptions = analyzeAndScoreCandidates(candidates: candidates)

        // Update sync state
        await updateSyncState(
            mode: effectiveMode,
            subscriptionCount: subscriptions.count,
            emailsScanned: progress.emailsScanned,
            accessToken: accessToken
        )

        // Complete
        progress = ScanProgress(
            phase: .complete,
            emailsScanned: progress.emailsScanned,
            candidatesFound: subscriptions.count,
            hasGmailAccount: true,
            storeKitPhase: .unavailable,
            transactionsScanned: 0,
            storeKitCandidatesFound: 0
        )

        let duration = Date().timeIntervalSince(startTime)

        return DetectionResult(
            subscriptions: subscriptions.sorted { $0.confidence.score > $1.confidence.score },
            emailsScanned: progress.emailsScanned,
            scanDuration: duration
        )
    }

    /// Force a full scan (clears sync state)
    func forceFullScan(accessToken: String) async throws -> DetectionResult {
        await syncStateManager.clearState()
        await messageCache.clear()
        return try await scanForSubscriptions(accessToken: accessToken, mode: .full)
    }

    /// Check if incremental sync is available
    func canPerformIncrementalSync() async -> Bool {
        let state = await syncStateManager.getState()
        return state.canPerformIncrementalSync
    }

    /// Get last sync info for display
    func getLastSyncInfo() async -> (date: Date?, mode: String?) {
        let state = await syncStateManager.getState()
        let lastDate = state.lastIncrementalSyncDate ?? state.lastFullScanDate
        let mode = state.lastIncrementalSyncDate != nil ? "Quick Scan" : "Full Scan"
        return (lastDate, mode)
    }

    // MARK: - Scan Mode Helpers

    /// Determine the effective scan mode based on sync state
    private func determineEffectiveScanMode(
        requestedMode: ScanMode,
        accessToken: String
    ) async -> ScanMode {
        // If full scan requested, use it
        if requestedMode == .full {
            return .full
        }

        // Check if we have a valid history ID for incremental sync
        let state = await syncStateManager.getState()
        guard state.canPerformIncrementalSync else {
            // No history ID - must do full scan
            return .full
        }

        return .incremental
    }

    /// Perform an incremental scan using Gmail History API
    private func performIncrementalScan(accessToken: String) async throws -> [MerchantCandidate] {
        let state = await syncStateManager.getState()

        guard let lastHistoryId = state.lastHistoryId else {
            // No history ID - fall back to full scan
            return try await performFullScan(accessToken: accessToken)
        }

        // Try to get new messages since last sync
        let syncResult = try await gmailService.fetchNewMessageIds(
            accessToken: accessToken,
            startHistoryId: lastHistoryId
        )

        // If history expired, fall back to full scan
        if syncResult.historyExpired {
            return try await performFullScan(accessToken: accessToken)
        }

        // If no new messages, return empty (existing subscriptions still valid)
        guard !syncResult.newMessageIds.isEmpty else {
            progress.emailsScanned = 0
            return []
        }

        // Fetch details for new messages only
        let newMessages = try await gmailService.fetchMessagesByIds(
            accessToken: accessToken,
            messageIds: syncResult.newMessageIds,
            format: config.useMetadataOnlyMode ? .metadata : .full,
            useCache: true
        )

        progress.emailsScanned = newMessages.count

        // Update history ID
        await syncStateManager.updateHistoryId(syncResult.latestHistoryId)

        // Process new messages into candidates
        return groupMessagesIntoCandidates(newMessages)
    }

    /// Perform a full scan (all messages matching query)
    private func performFullScan(accessToken: String) async throws -> [MerchantCandidate] {
        // Get current history ID before scanning (for future incremental syncs)
        let currentHistoryId = try? await gmailService.getCurrentHistoryId(accessToken: accessToken)

        // Perform the full metadata scan
        let candidates = try await performMetadataScan(accessToken: accessToken)

        // Store history ID for future incremental syncs
        if let historyId = currentHistoryId {
            await syncStateManager.updateHistoryId(historyId)
        }

        return candidates
    }

    /// Update sync state after scan completion
    private func updateSyncState(
        mode: ScanMode,
        subscriptionCount: Int,
        emailsScanned: Int,
        accessToken: String
    ) async {
        switch mode {
        case .full:
            // Get fresh history ID
            let historyId = try? await gmailService.getCurrentHistoryId(accessToken: accessToken)
            let processedIds = await messageCache.getAllCachedIds()

            await syncStateManager.markFullScanComplete(
                historyId: historyId,
                processedIds: processedIds,
                subscriptionCount: subscriptionCount,
                emailsScanned: emailsScanned
            )

        case .incremental:
            let state = await syncStateManager.getState()
            if let historyId = state.lastHistoryId {
                let newIds = await messageCache.getAllCachedIds()
                await syncStateManager.markIncrementalSyncComplete(
                    historyId: historyId,
                    newMessageIds: newIds,
                    subscriptionCount: subscriptionCount
                )
            }
        }
    }

    /// Group messages into merchant candidates (shared by both scan modes)
    private func groupMessagesIntoCandidates(_ messages: [GmailMessage]) -> [MerchantCandidate] {
        var senderGroups: [String: [GmailMessage]] = [:]
        var paymentProcessorEmails: [GmailMessage] = []

        for message in messages {
            let senderDomain = extractSenderDomain(from: message.from)

            // Skip hard-excluded domains immediately
            guard !hardExcludeDomains.contains(senderDomain) else { continue }

            // Skip blocked domains
            guard !isBlockedDomain(senderDomain) else { continue }

            // Skip if sender looks like an individual person
            guard !looksLikeIndividual(message.from) else { continue }

            // Check if this is from a payment processor (needs special handling)
            if isPaymentProcessor(senderDomain) {
                paymentProcessorEmails.append(message)
            } else {
                senderGroups[senderDomain, default: []].append(message)
            }
        }

        // Convert direct senders to candidates
        var candidates: [MerchantCandidate] = []

        for (senderDomain, emails) in senderGroups {
            guard !emails.isEmpty else { continue }

            // Combine email content for better merchant matching (e.g., distinguishing iCloud from Apple Music)
            let emailContent = emails.map { "\($0.subject) \($0.snippet)" }.joined(separator: " ")

            let candidate = MerchantCandidate(
                senderDomain: senderDomain,
                senderEmail: emails.first?.from ?? "",
                emails: emails,
                knownMerchant: merchantDB.findMerchant(byDomain: senderDomain, emailContent: emailContent),
                isFromPaymentProcessor: false,
                extractedMerchantName: nil
            )

            candidates.append(candidate)
        }

        // Process payment processor emails to extract actual merchants
        let processorCandidates = processPaymentProcessorEmails(paymentProcessorEmails)
        candidates.append(contentsOf: processorCandidates)

        return candidates
    }

    // MARK: - Pass 1: Metadata Scan

    private func performMetadataScan(accessToken: String) async throws -> [MerchantCandidate] {
        let query = buildSearchQuery()

        let messages = try await gmailService.searchMessages(
            accessToken: accessToken,
            query: query,
            maxResults: config.maxEmailsToScan,
            metadataOnly: config.useMetadataOnlyMode
        )

        progress.emailsScanned = messages.count

        // Group by sender domain, with special handling for payment processors
        var senderGroups: [String: [GmailMessage]] = [:]
        var paymentProcessorEmails: [GmailMessage] = []

        for message in messages {
            let senderDomain = extractSenderDomain(from: message.from)

            // Skip hard-excluded domains immediately
            guard !hardExcludeDomains.contains(senderDomain) else { continue }

            // Skip blocked domains
            guard !isBlockedDomain(senderDomain) else { continue }

            // Skip if sender looks like an individual person
            guard !looksLikeIndividual(message.from) else { continue }

            // Check if this is from a payment processor (needs special handling)
            if isPaymentProcessor(senderDomain) {
                paymentProcessorEmails.append(message)
            } else {
                senderGroups[senderDomain, default: []].append(message)
            }
        }

        // Convert direct senders to candidates
        var candidates: [MerchantCandidate] = []

        for (senderDomain, emails) in senderGroups {
            guard !emails.isEmpty else { continue }

            // Combine email content for better merchant matching (e.g., distinguishing iCloud from Apple Music)
            let emailContent = emails.map { "\($0.subject) \($0.snippet)" }.joined(separator: " ")

            let candidate = MerchantCandidate(
                senderDomain: senderDomain,
                senderEmail: emails.first?.from ?? "",
                emails: emails,
                knownMerchant: merchantDB.findMerchant(byDomain: senderDomain, emailContent: emailContent),
                isFromPaymentProcessor: false,
                extractedMerchantName: nil
            )

            candidates.append(candidate)
        }

        // Process payment processor emails to extract actual merchants
        let processorCandidates = processPaymentProcessorEmails(paymentProcessorEmails)
        candidates.append(contentsOf: processorCandidates)

        return candidates
    }

    /// Build optimized Gmail search query using category filters and exclusions
    private func buildSearchQuery() -> String {
        // Core subscription keywords
        let positiveKeywords = [
            "subscription", "membership", "renewal", "auto-renewal",
            "recurring", "monthly plan", "annual plan", "yearly plan",
            "billing cycle", "next billing date",
            "invoice", "receipt"
        ].map { "\"\($0)\"" }.joined(separator: " OR ")

        // Negative keywords to exclude at query level (reduces API calls)
        let negativeKeywords = [
            "shipped", "tracking", "delivery",
            "order confirmation", "your order"
        ].map { "-\"\($0)\"" }.joined(separator: " ")

        var query = "newer_than:\(config.monthsToScan)m (\(positiveKeywords)) \(negativeKeywords)"

        // Use Gmail's category:purchases filter for better precision
        if config.useCategoryFilter {
            // Combine with category filter - this dramatically reduces noise
            query = "(category:purchases OR category:updates) \(query)"
        }

        return query
    }

    /// Check if domain is a payment processor requiring special handling
    private func isPaymentProcessor(_ domain: String) -> Bool {
        let lowercased = domain.lowercased()
        return paymentProcessorDomains.contains { lowercased.contains($0) }
    }

    /// Process emails from payment processors to extract actual merchant names
    private func processPaymentProcessorEmails(_ emails: [GmailMessage]) -> [MerchantCandidate] {
        var merchantGroups: [String: [GmailMessage]] = [:]

        for email in emails {
            // Try to extract the actual merchant name from the email
            if let merchantName = extractMerchantFromPaymentProcessor(email) {
                let normalizedName = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
                merchantGroups[normalizedName, default: []].append(email)
            }
        }

        return merchantGroups.compactMap { merchantName, emails -> MerchantCandidate? in
            guard !emails.isEmpty else { return nil }

            // Try to find this merchant in our database
            let knownMerchant = merchantDB.findMerchant(byKeyword: merchantName)

            return MerchantCandidate(
                senderDomain: extractSenderDomain(from: emails.first?.from ?? ""),
                senderEmail: emails.first?.from ?? "",
                emails: emails,
                knownMerchant: knownMerchant,
                isFromPaymentProcessor: true,
                extractedMerchantName: merchantName.capitalized
            )
        }
    }

    /// Extract merchant name from payment processor email content
    private func extractMerchantFromPaymentProcessor(_ email: GmailMessage) -> String? {
        let searchText = "\(email.subject) \(email.snippet)"

        for pattern in merchantExtractionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: searchText, range: NSRange(searchText.startIndex..., in: searchText)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: searchText) {
                let extracted = String(searchText[range])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,"))

                // Validate: must be reasonable length and not look like a generic term
                if extracted.count >= 2 && extracted.count <= 50 &&
                   !isGenericPaymentTerm(extracted) {
                    return extracted
                }
            }
        }

        return nil
    }

    /// Check if extracted name is just a generic payment term
    private func isGenericPaymentTerm(_ term: String) -> Bool {
        let genericTerms: Set<String> = [
            "payment", "subscription", "recurring", "charge",
            "invoice", "receipt", "billing", "automatic",
            "monthly", "annual", "yearly", "your"
        ]
        return genericTerms.contains(term.lowercased())
    }

    private func extractSenderDomain(from sender: String) -> String {
        let email = sender.lowercased()

        if let start = email.lastIndex(of: "<"),
           let end = email.lastIndex(of: ">") {
            let emailPart = String(email[email.index(after: start)..<end])
            if let atIndex = emailPart.lastIndex(of: "@") {
                return String(emailPart[emailPart.index(after: atIndex)...])
            }
        }

        if let atIndex = email.lastIndex(of: "@") {
            return String(email[email.index(after: atIndex)...])
        }

        return email
    }

    // MARK: - Filtering

    private func isBlockedDomain(_ domain: String) -> Bool {
        let lowercaseDomain = domain.lowercased()

        // Check exact match
        if blockedDomains.contains(lowercaseDomain) {
            return true
        }

        // Check if domain ends with blocked domain (e.g., mail.bankofamerica.com)
        for blocked in blockedDomains {
            if lowercaseDomain.hasSuffix(".\(blocked)") || lowercaseDomain == blocked {
                return true
            }
        }

        return false
    }

    private func looksLikeIndividual(_ sender: String) -> Bool {
        let lowercaseSender = sender.lowercased()

        // Check for individual patterns
        for pattern in individualPatterns {
            if lowercaseSender.contains(pattern) {
                return true
            }
        }

        // Check if sender name looks like "First Last" without company indicators
        // Extract name part before email
        if let angleIndex = sender.firstIndex(of: "<") {
            let name = String(sender[..<angleIndex]).trimmingCharacters(in: .whitespaces)
            let lowercaseName = name.lowercased()

            // Skip if in quotes (often indicates individual on PayPal etc)
            if name.hasPrefix("\"") && name.hasSuffix("\"") {
                return true
            }

            // Skip names with "via" (e.g., "John Smith via PayPal")
            if lowercaseName.contains(" via ") {
                return true
            }
        }

        return false
    }

    // MARK: - Pass 2: Analysis & Scoring

    private func analyzeAndScoreCandidates(candidates: [MerchantCandidate]) -> [Subscription] {
        var subscriptions: [Subscription] = []

        for candidate in candidates {
            // Update progress with current merchant being analyzed
            progress.currentMerchant = candidate.extractedMerchantName
                ?? candidate.knownMerchant?.name
                ?? candidate.senderDomain

            let analysis = analyzeCandidate(candidate)

            // Skip candidates below minimum threshold
            guard analysis.score >= config.minConfidenceScore else { continue }

            // Skip if price is invalid or missing
            guard let price = analysis.price, price > 0, price < 1000 else { continue }

            // Skip low confidence candidates
            guard analysis.confidence != .low else { continue }

            // CRITICAL: Skip if subscription appears cancelled
            guard !analysis.hasCancellationSignal else { continue }

            // CRITICAL: Skip if subscription appears stale (no recent activity)
            guard isSubscriptionCurrentlyActive(
                lastChargeDate: analysis.lastChargeDate,
                billingCycle: analysis.billingCycle
            ) else { continue }

            let subscription = Subscription(
                merchantId: candidate.knownMerchant?.id ?? candidate.senderDomain,
                name: analysis.merchantName,
                price: price,
                billingCycle: analysis.billingCycle,
                confidence: analysis.confidence,
                nextBillingDate: analysis.nextBillingDate,
                lastChargeDate: analysis.lastChargeDate,
                emailCount: candidate.emails.count,
                senderEmail: candidate.senderEmail,
                detectionSource: .gmail
            )

            subscriptions.append(subscription)
        }

        // Deduplicate by merchant name (keep highest confidence)
        let deduped = Dictionary(grouping: subscriptions) { $0.name.lowercased() }
            .compactMapValues { candidates -> Subscription? in
                candidates.max { $0.confidence.score < $1.confidence.score }
            }
            .values
            .map { $0 }

        return Array(deduped)
    }

    /// Check if a subscription appears to be currently active based on recency of last charge
    /// A subscription is considered active if last charge was within expected billing window + buffer
    private func isSubscriptionCurrentlyActive(lastChargeDate: Date?, billingCycle: BillingCycle) -> Bool {
        guard let lastCharge = lastChargeDate else {
            // No charge date means we can't verify - be conservative, skip it
            return false
        }

        let daysSinceLastCharge = Calendar.current.dateComponents(
            [.day],
            from: lastCharge,
            to: Date()
        ).day ?? Int.max

        // Expected max days between charges (billing cycle + generous buffer)
        let maxDaysAllowed: Int
        switch billingCycle {
        case .weekly:
            maxDaysAllowed = 14      // 7 days + 7 day buffer
        case .monthly:
            maxDaysAllowed = 45      // 30 days + 15 day buffer
        case .quarterly:
            maxDaysAllowed = 120     // 90 days + 30 day buffer
        case .yearly:
            maxDaysAllowed = 400     // 365 days + 35 day buffer
        case .unknown:
            maxDaysAllowed = 60      // Default to ~2 months for unknown cycles
        }

        return daysSinceLastCharge <= maxDaysAllowed
    }

    private func analyzeCandidate(_ candidate: MerchantCandidate) -> CandidateAnalysis {
        var score = 0

        // Known merchant boost
        if candidate.knownMerchant != nil {
            score += ScoringWeight.knownMerchant
        }

        // Payment processor with extracted merchant name bonus
        if candidate.isFromPaymentProcessor && candidate.extractedMerchantName != nil {
            score += ScoringWeight.paymentProcessorMerchantFound
        }

        // Analyze email content with enhanced scoring
        let contentAnalysis = analyzeEmailContent(candidate.emails)
        score += contentAnalysis.score

        // Check for recurring patterns
        let patternAnalysis = analyzeRecurringPattern(candidate.emails)
        score += patternAnalysis.score

        // Determine merchant name (priority: known > extracted > cleaned > domain)
        let merchantName: String
        if let known = candidate.knownMerchant?.name {
            merchantName = known
        } else if let extracted = candidate.extractedMerchantName {
            merchantName = extracted
        } else if let cleaned = cleanMerchantName(from: candidate.emails) {
            merchantName = cleaned
        } else {
            merchantName = formatDomainAsName(candidate.senderDomain)
        }

        // Determine final price with validation
        var finalPrice = contentAnalysis.detectedPrice
        if let merchant = candidate.knownMerchant,
           let typicalPrices = merchant.typicalPrices,
           let detected = finalPrice {
            // If detected price is way off from typical, use closest typical
            let minTypical = typicalPrices.min() ?? 0
            let maxTypical = typicalPrices.max() ?? 1000
            if detected < minTypical * 0.5 || detected > maxTypical * 2 {
                finalPrice = typicalPrices.min(by: { abs($0 - detected) < abs($1 - detected) })
            }
        }

        // Determine billing cycle (prefer pattern-detected, fall back to known merchant default)
        let billingCycle: BillingCycle
        if let detected = patternAnalysis.detectedCycle {
            billingCycle = detected
        } else if let merchant = candidate.knownMerchant {
            billingCycle = merchant.typicalCycle
        } else {
            billingCycle = patternAnalysis.billingCycle
        }

        // Determine confidence level
        let confidence: SubscriptionConfidence
        if score >= config.minHighConfidenceScore {
            confidence = .high
        } else if score >= config.minConfidenceScore {
            confidence = .medium
        } else {
            confidence = .low
        }

        return CandidateAnalysis(
            score: score,
            confidence: confidence,
            merchantName: merchantName,
            price: finalPrice,
            billingCycle: billingCycle,
            nextBillingDate: contentAnalysis.nextBillingDate,
            lastChargeDate: contentAnalysis.lastChargeDate,
            hasStructuralPattern: contentAnalysis.hasStructuralPattern,
            hasTrialSignal: contentAnalysis.hasTrialSignal,
            hasCancellationSignal: contentAnalysis.hasCancellationSignal
        )
    }

    // MARK: - Content Analysis

    private func analyzeEmailContent(_ emails: [GmailMessage]) -> ContentAnalysis {
        var score = 0
        var detectedPrices: [Double] = []
        var lastChargeDate: Date?
        var hasHardExclusion = false
        var hasAntiKeyword = false
        var hasStructuralPattern = false
        var hasTrialSignal = false
        var hasUnsubscribeHeader = false
        var hasCancellationSignal = false
        var mostRecentCancellationDate: Date?

        // Sort emails by date (newest first) to detect recent cancellations
        let sortedEmails = emails.sorted { $0.date > $1.date }

        for email in sortedEmails {
            let subject = email.subject.lowercased()
            let snippet = email.snippet.lowercased()
            let combined = subject + " " + snippet

            // Check for CANCELLATION signals (very important for accuracy)
            if !hasCancellationSignal {
                for keyword in cancellationKeywords {
                    if combined.contains(keyword) {
                        hasCancellationSignal = true
                        mostRecentCancellationDate = email.date
                        break
                    }
                }
            }

            // Check for hard exclusions FIRST (immediate reject)
            for keyword in hardExclusionKeywords {
                if combined.contains(keyword) {
                    hasHardExclusion = true
                    score += ScoringWeight.hardExclusionPenalty
                    break
                }
            }

            // If hard exclusion found, skip further positive analysis
            if hasHardExclusion { continue }

            // Check for soft anti-keywords (negative signal but not fatal)
            for keyword in antiKeywords {
                if combined.contains(keyword) {
                    hasAntiKeyword = true
                    score += ScoringWeight.antiKeywordPenalty
                    break
                }
            }

            // Check for structural price patterns (very strong signal)
            if !hasStructuralPattern {
                for pattern in structuralPricePatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                       regex.firstMatch(in: combined, range: NSRange(combined.startIndex..., in: combined)) != nil {
                        hasStructuralPattern = true
                        score += ScoringWeight.structuralPricePattern
                        break
                    }
                }
            }

            // Check for trial conversion signals
            if !hasTrialSignal {
                for keyword in trialKeywords {
                    if combined.contains(keyword) {
                        hasTrialSignal = true
                        score += ScoringWeight.trialConversion
                        break
                    }
                }
            }

            // Strong subscription keywords
            var foundStrong = false
            for keyword in strongSubscriptionKeywords {
                if combined.contains(keyword) && !foundStrong {
                    score += ScoringWeight.strongKeyword
                    foundStrong = true
                }
            }

            // Medium keywords (only if no strong keyword found)
            if !foundStrong {
                for keyword in mediumSubscriptionKeywords {
                    if combined.contains(keyword) {
                        score += ScoringWeight.mediumKeyword
                        break
                    }
                }
            }

            // Extract price with enhanced patterns
            if let price = extractPrice(from: combined) {
                if price >= 0.99 && price <= 500 {
                    detectedPrices.append(price)
                }
            }

            // Check for List-Unsubscribe header (common in legit subscription emails)
            if email.hasUnsubscribeHeader && !hasUnsubscribeHeader {
                hasUnsubscribeHeader = true
                score += ScoringWeight.hasUnsubscribeHeader
            }

            // Track latest charge date
            if lastChargeDate == nil || email.date > lastChargeDate! {
                lastChargeDate = email.date
            }
        }

        // Consistent pricing bonus
        if detectedPrices.count >= 2 {
            let uniquePrices = Set(detectedPrices.map { round($0 * 100) / 100 })
            if uniquePrices.count == 1 {
                score += ScoringWeight.consistentPricing
            }
        }

        // Find most common valid price
        let validPrices = detectedPrices.filter { $0 >= 0.99 && $0 <= 500 }
        let mostCommonPrice = validPrices.isEmpty ? nil :
            Dictionary(grouping: validPrices) { round($0 * 100) / 100 }
                .max { $0.value.count < $1.value.count }?.key

        // Hard exclusion found = zero score
        if hasHardExclusion {
            score = 0
        }

        return ContentAnalysis(
            score: max(score, 0),
            detectedPrice: mostCommonPrice,
            lastChargeDate: lastChargeDate,
            nextBillingDate: nil,
            hasStructuralPattern: hasStructuralPattern,
            hasTrialSignal: hasTrialSignal,
            hasCancellationSignal: hasCancellationSignal
        )
    }

    /// Extract price from text with enhanced pattern matching
    private func extractPrice(from text: String) -> Double? {
        // Prioritize structural patterns first (more reliable)
        let structuralPatterns = [
            #"\$(\d{1,3}(?:\.\d{2})?)\s*/\s*(?:mo|month|yr|year)"#,  // $9.99/mo
            #"\$(\d{1,3}(?:\.\d{2})?)\s*per\s*(?:month|year)"#,      // $9.99 per month
        ]

        // Try structural patterns first
        for pattern in structuralPatterns {
            if let price = extractFirstPrice(from: text, pattern: pattern) {
                return price
            }
        }

        // Fall back to basic price patterns
        let basicPatterns = [
            #"\$(\d{1,3}(?:\.\d{2})?)"#,         // $9.99
            #"USD\s*(\d{1,3}(?:\.\d{2})?)"#,     // USD 9.99
            #"€(\d{1,3}(?:[,\.]\d{2})?)"#,       // €9,99 or €9.99
        ]

        for pattern in basicPatterns {
            if let price = extractFirstPrice(from: text, pattern: pattern) {
                return price
            }
        }

        return nil
    }

    /// Helper to extract price from regex match
    private func extractFirstPrice(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        var priceString = String(text[range])
        // Handle European format (comma as decimal)
        priceString = priceString.replacingOccurrences(of: ",", with: ".")

        return Double(priceString)
    }

    // MARK: - Pattern Analysis

    private func analyzeRecurringPattern(_ emails: [GmailMessage]) -> PatternAnalysis {
        var score = 0
        var billingCycle: BillingCycle = .monthly // Default
        var detectedCycle: BillingCycle?

        guard emails.count >= 2 else {
            // Single email - can't determine pattern, lower confidence
            return PatternAnalysis(score: 5, billingCycle: .unknown, intervalVariance: nil)
        }

        let sortedEmails = emails.sorted { $0.date < $1.date }

        var intervals: [Int] = []
        for i in 1..<sortedEmails.count {
            let days = Calendar.current.dateComponents(
                [.day],
                from: sortedEmails[i-1].date,
                to: sortedEmails[i].date
            ).day ?? 0

            // Only count reasonable intervals (5-400 days)
            if days >= 5 && days <= 400 {
                intervals.append(days)
            }
        }

        guard !intervals.isEmpty else {
            return PatternAnalysis(score: 5, billingCycle: .unknown, intervalVariance: nil)
        }

        let avgInterval = intervals.reduce(0, +) / intervals.count

        // Determine billing cycle with ranges informed by real-world variance
        switch avgInterval {
        case 6...8:
            billingCycle = .weekly
            detectedCycle = .weekly
            score += ScoringWeight.recurringWeekly
        case 25...35:
            billingCycle = .monthly
            detectedCycle = .monthly
            score += ScoringWeight.recurringMonthly
        case 85...100:
            billingCycle = .quarterly
            detectedCycle = .quarterly
            score += ScoringWeight.recurringQuarterly
        case 355...375:
            billingCycle = .yearly
            detectedCycle = .yearly
            score += ScoringWeight.recurringYearly
        default:
            // Try to infer from closest match
            billingCycle = inferBillingCycle(from: avgInterval)
            score += 5
        }

        // Calculate variance for consistency bonus
        let variance = intervals.map { abs($0 - avgInterval) }.reduce(0, +) / max(intervals.count, 1)

        // Consistency bonus - very consistent intervals are strong signal
        if intervals.count >= 2 {
            if variance <= 3 {
                score += ScoringWeight.consistencyBonus // Very consistent
            } else if variance <= 7 {
                score += ScoringWeight.consistencyBonus / 2
            }
        }

        // Multiple emails bonus
        if emails.count >= 3 { score += ScoringWeight.multipleEmails }
        if emails.count >= 6 { score += ScoringWeight.manyEmails }

        return PatternAnalysis(
            score: score,
            billingCycle: billingCycle,
            intervalVariance: variance,
            detectedCycle: detectedCycle
        )
    }

    /// Infer billing cycle from interval that doesn't match standard patterns
    private func inferBillingCycle(from avgInterval: Int) -> BillingCycle {
        // Find closest match
        let cycles: [(BillingCycle, Int)] = [
            (.weekly, 7),
            (.monthly, 30),
            (.quarterly, 90),
            (.yearly, 365)
        ]

        return cycles.min { abs($0.1 - avgInterval) < abs($1.1 - avgInterval) }?.0 ?? .monthly
    }

    // MARK: - Helpers

    private func cleanMerchantName(from emails: [GmailMessage]) -> String? {
        guard let email = emails.first else { return nil }

        let sender = email.from
        if let endIndex = sender.firstIndex(of: "<") {
            var name = String(sender[..<endIndex]).trimmingCharacters(in: .whitespaces)

            // Remove quotes
            name = name.replacingOccurrences(of: "\"", with: "")

            // Skip if looks like individual
            if looksLikeIndividual(sender) { return nil }

            if !name.isEmpty && name.count < 40 {
                return name
            }
        }

        return nil
    }

    private func formatDomainAsName(_ domain: String) -> String {
        let name = domain.components(separatedBy: ".").first ?? domain
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

// MARK: - Internal Models

private struct MerchantCandidate {
    let senderDomain: String
    let senderEmail: String
    let emails: [GmailMessage]
    let knownMerchant: MerchantInfo?
    let isFromPaymentProcessor: Bool
    let extractedMerchantName: String?

    init(
        senderDomain: String,
        senderEmail: String,
        emails: [GmailMessage],
        knownMerchant: MerchantInfo?,
        isFromPaymentProcessor: Bool = false,
        extractedMerchantName: String? = nil
    ) {
        self.senderDomain = senderDomain
        self.senderEmail = senderEmail
        self.emails = emails
        self.knownMerchant = knownMerchant
        self.isFromPaymentProcessor = isFromPaymentProcessor
        self.extractedMerchantName = extractedMerchantName
    }
}

private struct CandidateAnalysis {
    let score: Int
    let confidence: SubscriptionConfidence
    let merchantName: String
    let price: Double?
    let billingCycle: BillingCycle
    let nextBillingDate: Date?
    let lastChargeDate: Date?
    let hasStructuralPattern: Bool
    let hasTrialSignal: Bool
    let hasCancellationSignal: Bool
}

private struct ContentAnalysis {
    let score: Int
    let detectedPrice: Double?
    let lastChargeDate: Date?
    let nextBillingDate: Date?
    let hasStructuralPattern: Bool
    let hasTrialSignal: Bool
    let hasCancellationSignal: Bool

    init(
        score: Int,
        detectedPrice: Double?,
        lastChargeDate: Date?,
        nextBillingDate: Date?,
        hasStructuralPattern: Bool = false,
        hasTrialSignal: Bool = false,
        hasCancellationSignal: Bool = false
    ) {
        self.score = score
        self.detectedPrice = detectedPrice
        self.lastChargeDate = lastChargeDate
        self.nextBillingDate = nextBillingDate
        self.hasStructuralPattern = hasStructuralPattern
        self.hasTrialSignal = hasTrialSignal
        self.hasCancellationSignal = hasCancellationSignal
    }
}

private struct PatternAnalysis {
    let score: Int
    let billingCycle: BillingCycle
    let intervalVariance: Int?
    let detectedCycle: BillingCycle?

    init(score: Int, billingCycle: BillingCycle, intervalVariance: Int? = nil, detectedCycle: BillingCycle? = nil) {
        self.score = score
        self.billingCycle = billingCycle
        self.intervalVariance = intervalVariance
        self.detectedCycle = detectedCycle
    }
}
