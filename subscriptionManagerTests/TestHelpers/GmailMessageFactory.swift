//
//  GmailMessageFactory.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation
@testable import subscriptionManager

/// Factory for creating test GmailMessage instances
enum GmailMessageFactory {

    // MARK: - Basic Message Creation

    /// Create a basic GmailMessage
    static func createMessage(
        id: String = UUID().uuidString,
        threadId: String = UUID().uuidString,
        subject: String = "Test Subject",
        from: String = "test@example.com",
        snippet: String = "Test snippet content",
        date: Date = Date(),
        hasUnsubscribeHeader: Bool = false
    ) -> GmailMessage {
        var headers: [MessageHeader] = [
            MessageHeader(name: "Subject", value: subject),
            MessageHeader(name: "From", value: from),
            MessageHeader(name: "Date", value: ISO8601DateFormatter().string(from: date))
        ]

        if hasUnsubscribeHeader {
            headers.append(MessageHeader(name: "List-Unsubscribe", value: "<mailto:unsubscribe@example.com>"))
        }

        let payload = MessagePayload(
            headers: headers,
            body: MessageBody(data: nil)
        )

        return GmailMessage(
            id: id,
            threadId: threadId,
            snippet: snippet,
            payload: payload,
            internalDate: date.gmailInternalDate
        )
    }

    // MARK: - Subscription Email Presets

    /// Netflix subscription confirmation email
    static func netflixSubscription(
        date: Date = Date(),
        price: String = "$15.99"
    ) -> GmailMessage {
        createMessage(
            subject: "Your Netflix subscription is confirmed",
            from: "Netflix <info@mailer.netflix.com>",
            snippet: "Thank you for subscribing to Netflix. Your \(price)/mo plan is now active. Your next billing date is...",
            date: date,
            hasUnsubscribeHeader: true
        )
    }

    /// Netflix renewal email
    static func netflixRenewal(
        date: Date = Date(),
        price: String = "$15.99"
    ) -> GmailMessage {
        createMessage(
            subject: "Your Netflix subscription has renewed",
            from: "Netflix <info@mailer.netflix.com>",
            snippet: "Your Netflix subscription has automatically renewed. Amount charged: \(price). Thanks for being a member!",
            date: date,
            hasUnsubscribeHeader: true
        )
    }

    /// Spotify subscription receipt
    static func spotifyReceipt(
        date: Date = Date(),
        price: String = "$10.99"
    ) -> GmailMessage {
        createMessage(
            subject: "Your Spotify Premium receipt",
            from: "Spotify <no-reply@spotify.com>",
            snippet: "Thanks for your payment. Receipt for Spotify Premium - \(price)/month. Your subscription renews on...",
            date: date,
            hasUnsubscribeHeader: true
        )
    }

    /// Adobe Creative Cloud subscription
    static func adobeSubscription(
        date: Date = Date(),
        price: String = "$54.99"
    ) -> GmailMessage {
        createMessage(
            subject: "Your Adobe Creative Cloud subscription invoice",
            from: "Adobe <mail@email.adobe.com>",
            snippet: "Invoice for Adobe Creative Cloud All Apps. Monthly subscription: \(price)/mo. Thanks for being a subscriber.",
            date: date,
            hasUnsubscribeHeader: true
        )
    }

    /// PayPal payment to merchant
    static func paypalPayment(
        merchant: String,
        date: Date = Date(),
        price: String = "$9.99"
    ) -> GmailMessage {
        createMessage(
            subject: "Receipt for your payment to \(merchant)",
            from: "PayPal <service@paypal.com>",
            snippet: "You sent an automatic payment of \(price) USD to \(merchant). Transaction ID: ABC123...",
            date: date,
            hasUnsubscribeHeader: false
        )
    }

    /// Stripe receipt
    static func stripeReceipt(
        merchant: String,
        date: Date = Date(),
        price: String = "$19.99"
    ) -> GmailMessage {
        createMessage(
            subject: "Receipt from \(merchant)",
            from: "Stripe <receipts@stripe.com>",
            snippet: "Receipt from \(merchant). Amount charged: \(price). Thank you for your payment.",
            date: date,
            hasUnsubscribeHeader: false
        )
    }

    // MARK: - Non-Subscription Email Presets (False Positives to Reject)

    /// Bank statement notification
    static func bankStatement(
        bankName: String = "Bank of America",
        date: Date = Date()
    ) -> GmailMessage {
        createMessage(
            subject: "Your \(bankName) statement is ready",
            from: "\(bankName) <alerts@\(bankName.lowercased().replacingOccurrences(of: " ", with: "")).com>",
            snippet: "Your monthly statement is now available. Account ending in 4521. View your statement online...",
            date: date
        )
    }

    /// Order confirmation (not subscription)
    static func orderConfirmation(
        merchant: String = "Amazon",
        date: Date = Date()
    ) -> GmailMessage {
        createMessage(
            subject: "Order confirmation #123-4567890",
            from: "\(merchant) <orders@\(merchant.lowercased()).com>",
            snippet: "Thanks for your order! Order #123-4567890. Your items will ship soon...",
            date: date
        )
    }

    /// Shipping notification
    static func shippingNotification(
        date: Date = Date()
    ) -> GmailMessage {
        createMessage(
            subject: "Your package has shipped",
            from: "Amazon <shipment-tracking@amazon.com>",
            snippet: "Your package is on the way! Tracking number: 1Z999AA10123456784. Estimated delivery...",
            date: date
        )
    }

    /// Uber/Lyft trip receipt (not subscription)
    static func tripReceipt(
        service: String = "Uber",
        date: Date = Date()
    ) -> GmailMessage {
        createMessage(
            subject: "Your Thursday evening trip with \(service)",
            from: "\(service) Receipts <noreply@\(service.lowercased()).com>",
            snippet: "Thanks for riding with \(service). Trip receipt: $23.50. Trip on Thursday evening...",
            date: date
        )
    }

    /// Venmo transfer (hard exclude)
    static func venmoTransfer(
        date: Date = Date()
    ) -> GmailMessage {
        createMessage(
            subject: "John paid you $25.00",
            from: "Venmo <venmo@venmo.com>",
            snippet: "John paid you $25.00 for dinner. Your Venmo balance is now $75.00...",
            date: date
        )
    }

    /// Cancellation confirmation
    static func cancellationConfirmation(
        service: String = "Netflix",
        date: Date = Date()
    ) -> GmailMessage {
        createMessage(
            subject: "Your \(service) subscription has been cancelled",
            from: "\(service) <info@\(service.lowercased()).com>",
            snippet: "We're sorry to see you go. Your \(service) subscription has been successfully cancelled...",
            date: date,
            hasUnsubscribeHeader: true
        )
    }

    // MARK: - Email Sequence Generators

    /// Generate a sequence of emails for a subscription at monthly intervals
    static func monthlySubscriptionSequence(
        service: String,
        domain: String,
        price: String,
        count: Int,
        startDate: Date = Date.monthsFromNow(-6)
    ) -> [GmailMessage] {
        (0..<count).map { index in
            let date = Calendar.current.date(byAdding: .month, value: index, to: startDate)!
            return createMessage(
                subject: "Your \(service) subscription receipt",
                from: "\(service) <billing@\(domain)>",
                snippet: "Thank you for your payment of \(price). Your subscription will renew next month.",
                date: date,
                hasUnsubscribeHeader: true
            )
        }
    }

    /// Generate a sequence of emails for weekly billing
    static func weeklySubscriptionSequence(
        service: String,
        domain: String,
        price: String,
        count: Int,
        startDate: Date = Date.weeksFromNow(-8)
    ) -> [GmailMessage] {
        (0..<count).map { index in
            let date = Calendar.current.date(byAdding: .weekOfYear, value: index, to: startDate)!
            return createMessage(
                subject: "Your \(service) weekly receipt",
                from: "\(service) <billing@\(domain)>",
                snippet: "Weekly charge of \(price) processed. Thanks for your subscription!",
                date: date,
                hasUnsubscribeHeader: true
            )
        }
    }

    /// Generate a sequence with consistent 30-day intervals (for pattern testing)
    static func consistentMonthlySequence(
        count: Int,
        intervalDays: Int = 30,
        startDate: Date = Date.daysFromNow(-180)
    ) -> [GmailMessage] {
        (0..<count).map { index in
            let date = Calendar.current.date(byAdding: .day, value: index * intervalDays, to: startDate)!
            return createMessage(
                subject: "Your monthly subscription receipt",
                from: "Service <billing@service.com>",
                snippet: "Monthly charge of $9.99 processed successfully.",
                date: date,
                hasUnsubscribeHeader: true
            )
        }
    }

    /// Generate a sequence with variable intervals (for pattern variance testing)
    static func variableIntervalSequence(
        count: Int,
        baseInterval: Int = 30,
        variance: Int = 3,
        startDate: Date = Date.daysFromNow(-180)
    ) -> [GmailMessage] {
        var currentDate = startDate
        return (0..<count).map { _ in
            let message = createMessage(
                subject: "Your subscription receipt",
                from: "Service <billing@service.com>",
                snippet: "Monthly charge of $9.99 processed successfully.",
                date: currentDate,
                hasUnsubscribeHeader: true
            )
            let interval = baseInterval + Int.random(in: -variance...variance)
            currentDate = Calendar.current.date(byAdding: .day, value: interval, to: currentDate)!
            return message
        }
    }
}
