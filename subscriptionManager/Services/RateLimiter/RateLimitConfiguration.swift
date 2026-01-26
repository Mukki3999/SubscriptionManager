//
//  RateLimitConfiguration.swift
//  subscriptionManager
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Configuration constants for rate limiting behavior
struct RateLimitConfiguration {

    // MARK: - Retry Configuration

    /// Initial delay before first retry (in seconds)
    static let initialRetryDelay: TimeInterval = 1.0

    /// Maximum delay between retries (in seconds)
    static let maxRetryDelay: TimeInterval = 64.0

    /// Maximum number of retry attempts before giving up
    static let maxRetries: Int = 5

    /// Jitter range to prevent thundering herd (0.0 to 0.5 = 0% to 50% random addition)
    static let jitterRange: ClosedRange<Double> = 0.0...0.5

    // MARK: - Throttling Configuration

    /// Delay between batch requests to avoid hitting rate limits
    static let batchThrottleDelay: TimeInterval = 0.1

    // MARK: - Circuit Breaker Configuration

    /// Number of consecutive failures before circuit breaker opens
    static let circuitBreakerThreshold: Int = 5

    /// Time in seconds before circuit breaker attempts to close (half-open state)
    static let circuitBreakerResetTime: TimeInterval = 60.0

    // MARK: - Batch Size Configuration

    /// Minimum batch size when rate limited
    static let minBatchSize: Int = 5

    /// Maximum batch size under normal conditions
    static let maxBatchSize: Int = 20

    /// Default starting batch size
    static let defaultBatchSize: Int = 15

    // MARK: - Computed Properties

    /// Calculate retry delay with exponential backoff and jitter
    /// - Parameter attempt: The retry attempt number (0-based)
    /// - Returns: The delay to wait before retrying
    static func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        // Exponential backoff: initialDelay * 2^attempt
        let exponentialDelay = initialRetryDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxRetryDelay)

        // Add jitter to prevent thundering herd
        let jitter = Double.random(in: jitterRange)
        return cappedDelay * (1.0 + jitter)
    }
}
