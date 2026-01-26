//
//  AdaptiveBatchSizer.swift
//  subscriptionManager
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Actor that dynamically adjusts batch sizes based on API response patterns
actor AdaptiveBatchSizer {

    // MARK: - Properties

    /// Current batch size
    private var currentBatchSize: Int

    /// Count of consecutive successful batches
    private var successStreak: Int = 0

    /// Number of successful batches needed before increasing size
    private let successesBeforeIncrease: Int = 3

    /// Amount to decrease batch size on rate limit
    private let decreaseAmount: Int = 5

    /// Amount to increase batch size on success streak
    private let increaseAmount: Int = 2

    // MARK: - Initialization

    init(initialSize: Int = RateLimitConfiguration.defaultBatchSize) {
        self.currentBatchSize = min(
            max(initialSize, RateLimitConfiguration.minBatchSize),
            RateLimitConfiguration.maxBatchSize
        )
    }

    // MARK: - Public Methods

    /// Get the current recommended batch size
    func getCurrentBatchSize() -> Int {
        return currentBatchSize
    }

    /// Record a successful batch request
    func recordSuccess() {
        successStreak += 1

        // Gradually increase batch size after consecutive successes
        if successStreak >= successesBeforeIncrease {
            increase()
            successStreak = 0
        }
    }

    /// Record a rate-limited batch request
    func recordRateLimit() {
        successStreak = 0
        decrease()
    }

    /// Record a general failure (not rate limit)
    func recordFailure() {
        // Don't change batch size on non-rate-limit failures
        // Just reset the success streak
        successStreak = 0
    }

    /// Reset to default batch size
    func reset() {
        currentBatchSize = RateLimitConfiguration.defaultBatchSize
        successStreak = 0
    }

    /// Get statistics about the current state
    func getStats() -> (batchSize: Int, successStreak: Int) {
        return (currentBatchSize, successStreak)
    }

    // MARK: - Private Methods

    /// Increase batch size within bounds
    private func increase() {
        currentBatchSize = min(
            currentBatchSize + increaseAmount,
            RateLimitConfiguration.maxBatchSize
        )
    }

    /// Decrease batch size within bounds
    private func decrease() {
        currentBatchSize = max(
            currentBatchSize - decreaseAmount,
            RateLimitConfiguration.minBatchSize
        )
    }
}
