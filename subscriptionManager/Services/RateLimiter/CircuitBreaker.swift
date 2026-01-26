//
//  CircuitBreaker.swift
//  subscriptionManager
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Circuit breaker states
enum CircuitBreakerState {
    /// Normal operation - requests are allowed
    case closed
    /// Failure threshold exceeded - requests are blocked
    case open
    /// Testing if service has recovered - limited requests allowed
    case halfOpen
}

/// Actor that implements the circuit breaker pattern to prevent cascading failures
actor CircuitBreaker {

    // MARK: - Properties

    /// Current circuit breaker state
    private(set) var state: CircuitBreakerState = .closed

    /// Count of consecutive failures
    private var failureCount: Int = 0

    /// Timestamp when the circuit breaker opened
    private var openedAt: Date?

    /// Number of requests allowed in half-open state
    private var halfOpenAttempts: Int = 0

    /// Maximum half-open attempts before deciding to close or re-open
    private let maxHalfOpenAttempts: Int = 2

    // MARK: - Public Methods

    /// Check if a request is allowed to proceed
    /// - Returns: true if the request can proceed, false if blocked
    func canProceed() -> Bool {
        switch state {
        case .closed:
            return true

        case .open:
            // Check if reset time has passed
            if let openedAt = openedAt,
               Date().timeIntervalSince(openedAt) >= RateLimitConfiguration.circuitBreakerResetTime {
                // Transition to half-open state
                state = .halfOpen
                halfOpenAttempts = 0
                return true
            }
            return false

        case .halfOpen:
            // Allow limited requests in half-open state
            return halfOpenAttempts < maxHalfOpenAttempts
        }
    }

    /// Record a successful request
    func recordSuccess() {
        switch state {
        case .closed:
            // Reset failure count on success
            failureCount = 0

        case .halfOpen:
            halfOpenAttempts += 1
            // If we've had enough successful requests, close the circuit
            if halfOpenAttempts >= maxHalfOpenAttempts {
                close()
            }

        case .open:
            // Shouldn't happen, but handle gracefully
            break
        }
    }

    /// Record a failed request
    func recordFailure() {
        switch state {
        case .closed:
            failureCount += 1
            if failureCount >= RateLimitConfiguration.circuitBreakerThreshold {
                open()
            }

        case .halfOpen:
            // Immediately re-open on failure in half-open state
            open()

        case .open:
            // Already open, nothing to do
            break
        }
    }

    /// Get time remaining until circuit breaker resets (nil if not open)
    var timeUntilReset: TimeInterval? {
        guard state == .open, let openedAt = openedAt else { return nil }
        let elapsed = Date().timeIntervalSince(openedAt)
        let remaining = RateLimitConfiguration.circuitBreakerResetTime - elapsed
        return remaining > 0 ? remaining : nil
    }

    /// Get the current failure count
    var currentFailureCount: Int {
        failureCount
    }

    /// Manually reset the circuit breaker to closed state
    func reset() {
        close()
    }

    // MARK: - Private Methods

    /// Transition to open state
    private func open() {
        state = .open
        openedAt = Date()
        halfOpenAttempts = 0
    }

    /// Transition to closed state
    private func close() {
        state = .closed
        failureCount = 0
        openedAt = nil
        halfOpenAttempts = 0
    }
}
