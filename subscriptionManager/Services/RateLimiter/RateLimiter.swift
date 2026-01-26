//
//  RateLimiter.swift
//  subscriptionManager
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Actor that handles rate limiting with exponential backoff for API requests
actor RateLimiter {

    // MARK: - Properties

    /// Timestamp of the last request made
    private var lastRequestTime: Date?

    /// Current retry attempt count
    private var currentRetryAttempt: Int = 0

    /// Whether we're currently in a backoff state
    private var isInBackoff: Bool = false

    /// Time when we can next make a request (if rate limited)
    private var nextAllowedRequestTime: Date?

    // MARK: - Public Methods

    /// Wait for the appropriate time before making a request
    func waitForNextRequest() async {
        // If we have a scheduled next request time, wait until then
        if let nextTime = nextAllowedRequestTime, nextTime > Date() {
            let waitTime = nextTime.timeIntervalSinceNow
            if waitTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        // Apply throttle delay between requests
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < RateLimitConfiguration.batchThrottleDelay {
                let remainingDelay = RateLimitConfiguration.batchThrottleDelay - timeSinceLastRequest
                try? await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
            }
        }

        lastRequestTime = Date()
    }

    /// Calculate and apply backoff delay for a retry attempt
    /// - Returns: The delay that was applied
    @discardableResult
    func applyBackoff() async -> TimeInterval {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: currentRetryAttempt)
        currentRetryAttempt += 1
        isInBackoff = true

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        return delay
    }

    /// Parse Retry-After header and set next allowed request time
    /// - Parameter header: The Retry-After header value
    func parseRetryAfterHeader(_ header: String?) {
        guard let header = header else { return }

        // Try parsing as seconds first
        if let seconds = TimeInterval(header) {
            nextAllowedRequestTime = Date().addingTimeInterval(seconds)
            return
        }

        // Try parsing as HTTP date (RFC 7231)
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")

        // HTTP-date format: "Wed, 21 Oct 2015 07:28:00 GMT"
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = dateFormatter.date(from: header) {
            nextAllowedRequestTime = date
            return
        }

        // RFC 850 format: "Wednesday, 21-Oct-15 07:28:00 GMT"
        dateFormatter.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss zzz"
        if let date = dateFormatter.date(from: header) {
            nextAllowedRequestTime = date
            return
        }

        // ANSI C format: "Wed Oct 21 07:28:00 2015"
        dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        if let date = dateFormatter.date(from: header) {
            nextAllowedRequestTime = date
        }
    }

    /// Check if we've exceeded the maximum retry attempts
    var hasExceededMaxRetries: Bool {
        currentRetryAttempt >= RateLimitConfiguration.maxRetries
    }

    /// Reset retry state after a successful request
    func resetRetryState() {
        currentRetryAttempt = 0
        isInBackoff = false
        nextAllowedRequestTime = nil
    }

    /// Get the current retry attempt count
    var retryAttempt: Int {
        currentRetryAttempt
    }

    /// Get the time until the next allowed request (nil if no restriction)
    var timeUntilNextRequest: TimeInterval? {
        guard let nextTime = nextAllowedRequestTime else { return nil }
        let remaining = nextTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
}
