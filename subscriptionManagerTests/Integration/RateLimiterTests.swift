//
//  RateLimiterTests.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import XCTest
@testable import subscriptionManager

/// Tests for rate limiting infrastructure
final class RateLimiterTests: XCTestCase {

    // MARK: - RateLimitConfiguration Tests

    func testConfiguration_InitialRetryDelay_IsOneSecond() {
        XCTAssertEqual(RateLimitConfiguration.initialRetryDelay, 1.0)
    }

    func testConfiguration_MaxRetryDelay_Is64Seconds() {
        XCTAssertEqual(RateLimitConfiguration.maxRetryDelay, 64.0)
    }

    func testConfiguration_MaxRetries_Is5() {
        XCTAssertEqual(RateLimitConfiguration.maxRetries, 5)
    }

    func testConfiguration_JitterRange_IsZeroToHalf() {
        XCTAssertEqual(RateLimitConfiguration.jitterRange.lowerBound, 0.0)
        XCTAssertEqual(RateLimitConfiguration.jitterRange.upperBound, 0.5)
    }

    func testConfiguration_BatchThrottleDelay_Is100ms() {
        XCTAssertEqual(RateLimitConfiguration.batchThrottleDelay, 0.1)
    }

    func testConfiguration_CircuitBreakerThreshold_Is5() {
        XCTAssertEqual(RateLimitConfiguration.circuitBreakerThreshold, 5)
    }

    func testConfiguration_CircuitBreakerResetTime_Is60Seconds() {
        XCTAssertEqual(RateLimitConfiguration.circuitBreakerResetTime, 60.0)
    }

    func testConfiguration_MinBatchSize_Is5() {
        XCTAssertEqual(RateLimitConfiguration.minBatchSize, 5)
    }

    func testConfiguration_MaxBatchSize_Is20() {
        XCTAssertEqual(RateLimitConfiguration.maxBatchSize, 20)
    }

    func testConfiguration_DefaultBatchSize_Is15() {
        XCTAssertEqual(RateLimitConfiguration.defaultBatchSize, 15)
    }

    // MARK: - Exponential Backoff Tests

    func testRetryDelay_FirstAttempt_IsAroundOneSecond() {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: 0)
        // 1.0 * (1.0 to 1.5) = 1.0 to 1.5 seconds
        XCTAssertGreaterThanOrEqual(delay, 1.0)
        XCTAssertLessThanOrEqual(delay, 1.5)
    }

    func testRetryDelay_SecondAttempt_IsAroundTwoSeconds() {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: 1)
        // 2.0 * (1.0 to 1.5) = 2.0 to 3.0 seconds
        XCTAssertGreaterThanOrEqual(delay, 2.0)
        XCTAssertLessThanOrEqual(delay, 3.0)
    }

    func testRetryDelay_ThirdAttempt_IsAroundFourSeconds() {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: 2)
        // 4.0 * (1.0 to 1.5) = 4.0 to 6.0 seconds
        XCTAssertGreaterThanOrEqual(delay, 4.0)
        XCTAssertLessThanOrEqual(delay, 6.0)
    }

    func testRetryDelay_FourthAttempt_IsAroundEightSeconds() {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: 3)
        // 8.0 * (1.0 to 1.5) = 8.0 to 12.0 seconds
        XCTAssertGreaterThanOrEqual(delay, 8.0)
        XCTAssertLessThanOrEqual(delay, 12.0)
    }

    func testRetryDelay_FifthAttempt_IsAroundSixteenSeconds() {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: 4)
        // 16.0 * (1.0 to 1.5) = 16.0 to 24.0 seconds
        XCTAssertGreaterThanOrEqual(delay, 16.0)
        XCTAssertLessThanOrEqual(delay, 24.0)
    }

    func testRetryDelay_LargeAttempt_CappedAtMax() {
        let delay = RateLimitConfiguration.retryDelay(forAttempt: 10)
        // Should be capped at 64 * 1.5 = 96 seconds max
        XCTAssertLessThanOrEqual(delay, 64.0 * 1.5)
    }

    // MARK: - RateLimiter Actor Tests

    func testRateLimiter_InitialState_CanProceed() async {
        let limiter = RateLimiter()

        // Initial state should allow requests
        let hasExceeded = await limiter.hasExceededMaxRetries
        XCTAssertFalse(hasExceeded)
    }

    func testRateLimiter_RetryAttempt_Increments() async {
        let limiter = RateLimiter()

        let initialAttempt = await limiter.retryAttempt
        XCTAssertEqual(initialAttempt, 0)

        // Apply backoff increases attempt
        await limiter.applyBackoff()
        let afterFirstBackoff = await limiter.retryAttempt
        XCTAssertEqual(afterFirstBackoff, 1)
    }

    func testRateLimiter_ResetState_ClearsAttempts() async {
        let limiter = RateLimiter()

        // Apply some backoffs
        await limiter.applyBackoff()
        await limiter.applyBackoff()

        let beforeReset = await limiter.retryAttempt
        XCTAssertEqual(beforeReset, 2)

        // Reset
        await limiter.resetRetryState()

        let afterReset = await limiter.retryAttempt
        XCTAssertEqual(afterReset, 0)
    }

    func testRateLimiter_MaxRetries_Detected() async {
        let limiter = RateLimiter()

        // Apply max retries
        for _ in 0..<RateLimitConfiguration.maxRetries {
            await limiter.applyBackoff()
        }

        let hasExceeded = await limiter.hasExceededMaxRetries
        XCTAssertTrue(hasExceeded)
    }

    // MARK: - Retry-After Header Parsing Tests

    func testRetryAfterParsing_Seconds_ParsesCorrectly() async {
        let limiter = RateLimiter()

        await limiter.parseRetryAfterHeader("30")

        let timeUntil = await limiter.timeUntilNextRequest
        XCTAssertNotNil(timeUntil)
        if let time = timeUntil {
            XCTAssertGreaterThan(time, 0)
            XCTAssertLessThanOrEqual(time, 30)
        }
    }

    func testRetryAfterParsing_Nil_NoRestriction() async {
        let limiter = RateLimiter()

        await limiter.parseRetryAfterHeader(nil)

        let timeUntil = await limiter.timeUntilNextRequest
        XCTAssertNil(timeUntil)
    }

    // MARK: - CircuitBreaker Tests

    func testCircuitBreaker_InitialState_IsClosed() async {
        let breaker = CircuitBreaker()
        let state = await breaker.state
        XCTAssertEqual(state, .closed)
    }

    func testCircuitBreaker_CanProceed_WhenClosed() async {
        let breaker = CircuitBreaker()
        let canProceed = await breaker.canProceed()
        XCTAssertTrue(canProceed)
    }

    func testCircuitBreaker_SuccessResets_FailureCount() async {
        let breaker = CircuitBreaker()

        // Record some failures
        for _ in 0..<3 {
            await breaker.recordFailure()
        }

        let beforeSuccess = await breaker.currentFailureCount
        XCTAssertEqual(beforeSuccess, 3)

        // Success resets count
        await breaker.recordSuccess()

        let afterSuccess = await breaker.currentFailureCount
        XCTAssertEqual(afterSuccess, 0)
    }

    func testCircuitBreaker_ThresholdFailures_OpensCircuit() async {
        let breaker = CircuitBreaker()

        // Record threshold failures
        for _ in 0..<RateLimitConfiguration.circuitBreakerThreshold {
            await breaker.recordFailure()
        }

        let state = await breaker.state
        XCTAssertEqual(state, .open)
    }

    func testCircuitBreaker_Open_BlocksRequests() async {
        let breaker = CircuitBreaker()

        // Open the circuit
        for _ in 0..<RateLimitConfiguration.circuitBreakerThreshold {
            await breaker.recordFailure()
        }

        let canProceed = await breaker.canProceed()
        XCTAssertFalse(canProceed)
    }

    func testCircuitBreaker_Reset_ClosesCircuit() async {
        let breaker = CircuitBreaker()

        // Open the circuit
        for _ in 0..<RateLimitConfiguration.circuitBreakerThreshold {
            await breaker.recordFailure()
        }

        // Reset
        await breaker.reset()

        let state = await breaker.state
        XCTAssertEqual(state, .closed)

        let canProceed = await breaker.canProceed()
        XCTAssertTrue(canProceed)
    }

    // MARK: - AdaptiveBatchSizer Tests

    func testBatchSizer_InitialSize_IsDefault() async {
        let sizer = AdaptiveBatchSizer()
        let size = await sizer.getCurrentBatchSize()
        XCTAssertEqual(size, RateLimitConfiguration.defaultBatchSize)
    }

    func testBatchSizer_RateLimit_DecreasesBatchSize() async {
        let sizer = AdaptiveBatchSizer()

        let initialSize = await sizer.getCurrentBatchSize()
        await sizer.recordRateLimit()
        let afterRateLimit = await sizer.getCurrentBatchSize()

        XCTAssertLessThan(afterRateLimit, initialSize)
    }

    func testBatchSizer_MultipleRateLimits_ReachesMinimum() async {
        let sizer = AdaptiveBatchSizer()

        // Apply many rate limits
        for _ in 0..<10 {
            await sizer.recordRateLimit()
        }

        let size = await sizer.getCurrentBatchSize()
        XCTAssertEqual(size, RateLimitConfiguration.minBatchSize)
    }

    func testBatchSizer_Successes_IncreasesBatchSize() async {
        let sizer = AdaptiveBatchSizer(initialSize: 10)

        // Record enough successes to trigger increase
        for _ in 0..<5 {
            await sizer.recordSuccess()
        }

        let size = await sizer.getCurrentBatchSize()
        XCTAssertGreaterThanOrEqual(size, 10)
    }

    func testBatchSizer_ManySuccesses_CapsAtMaximum() async {
        let sizer = AdaptiveBatchSizer()

        // Record many successes
        for _ in 0..<50 {
            await sizer.recordSuccess()
        }

        let size = await sizer.getCurrentBatchSize()
        XCTAssertLessThanOrEqual(size, RateLimitConfiguration.maxBatchSize)
    }

    func testBatchSizer_Reset_ReturnsToDefault() async {
        let sizer = AdaptiveBatchSizer()

        // Modify size
        await sizer.recordRateLimit()

        // Reset
        await sizer.reset()

        let size = await sizer.getCurrentBatchSize()
        XCTAssertEqual(size, RateLimitConfiguration.defaultBatchSize)
    }

    func testBatchSizer_Stats_ReturnsCorrectValues() async {
        let sizer = AdaptiveBatchSizer()

        await sizer.recordSuccess()
        await sizer.recordSuccess()

        let stats = await sizer.getStats()
        XCTAssertEqual(stats.successStreak, 2)
    }
}
