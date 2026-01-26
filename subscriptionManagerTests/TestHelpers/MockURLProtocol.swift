//
//  MockURLProtocol.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Mock URL protocol for intercepting network requests in tests
class MockURLProtocol: URLProtocol {

    // MARK: - Static Configuration

    /// Handler closure for mocking responses
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Queue of responses for sequential requests
    private static var responseQueue: [(HTTPURLResponse, Data)] = []

    /// Delay before returning response (simulates network latency)
    static var responseDelay: TimeInterval = 0

    /// Error to throw (if set, overrides normal response)
    static var errorToThrow: Error?

    // MARK: - URLProtocol Overrides

    override class func canInit(with request: URLRequest) -> Bool {
        // Handle all requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Add delay if configured
        if MockURLProtocol.responseDelay > 0 {
            Thread.sleep(forTimeInterval: MockURLProtocol.responseDelay)
        }

        // Check for forced error
        if let error = MockURLProtocol.errorToThrow {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        // Try response queue first
        if !MockURLProtocol.responseQueue.isEmpty {
            let (response, data) = MockURLProtocol.responseQueue.removeFirst()
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        // Fall back to request handler
        guard let handler = MockURLProtocol.requestHandler else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No request handler configured"
            ])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Nothing to do
    }

    // MARK: - Configuration Methods

    /// Reset all mock configuration
    static func reset() {
        requestHandler = nil
        responseQueue = []
        responseDelay = 0
        errorToThrow = nil
    }

    /// Queue a response for the next request
    static func queueResponse(
        statusCode: Int,
        data: Data,
        headers: [String: String]? = nil
    ) {
        guard let url = URL(string: "https://mock.test") else { return }
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        responseQueue.append((response, data))
    }

    /// Queue a successful JSON response
    static func queueJSONResponse<T: Encodable>(
        statusCode: Int = 200,
        body: T
    ) throws {
        let data = try JSONEncoder().encode(body)
        queueResponse(statusCode: statusCode, data: data, headers: ["Content-Type": "application/json"])
    }

    /// Queue a rate limit response (429)
    static func queueRateLimitResponse(retryAfter: String? = nil) {
        var headers: [String: String] = ["Content-Type": "application/json"]
        if let retryAfter = retryAfter {
            headers["Retry-After"] = retryAfter
        }
        queueResponse(
            statusCode: 429,
            data: Data("{\"error\": \"rate_limited\"}".utf8),
            headers: headers
        )
    }

    /// Queue an unauthorized response (401)
    static func queueUnauthorizedResponse() {
        queueResponse(
            statusCode: 401,
            data: Data("{\"error\": \"unauthorized\"}".utf8),
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Queue a server error response (500)
    static func queueServerErrorResponse() {
        queueResponse(
            statusCode: 500,
            data: Data("{\"error\": \"internal_server_error\"}".utf8),
            headers: ["Content-Type": "application/json"]
        )
    }

    /// Create a mock URLSession configuration
    static func mockSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }

    /// Create a mock URLSession
    static func mockSession() -> URLSession {
        URLSession(configuration: mockSessionConfiguration())
    }
}

// MARK: - Mock Response Helpers

extension HTTPURLResponse {

    /// Create a mock HTTP response
    static func mock(
        url: URL = URL(string: "https://mock.test")!,
        statusCode: Int,
        headers: [String: String]? = nil
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}
