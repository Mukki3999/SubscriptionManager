//
//  GmailMockResponses.swift
//  subscriptionManagerTests
//
//  Created by Claude on 1/25/26.
//

import Foundation

/// Mock JSON responses for Gmail API tests
enum GmailMockResponses {

    // MARK: - Message List Response

    static let messageListResponse = """
    {
        "messages": [
            {"id": "msg1", "threadId": "thread1"},
            {"id": "msg2", "threadId": "thread2"},
            {"id": "msg3", "threadId": "thread3"}
        ],
        "nextPageToken": null,
        "resultSizeEstimate": 3
    }
    """

    static let messageListWithPagination = """
    {
        "messages": [
            {"id": "msg1", "threadId": "thread1"},
            {"id": "msg2", "threadId": "thread2"}
        ],
        "nextPageToken": "page2token",
        "resultSizeEstimate": 10
    }
    """

    static let emptyMessageList = """
    {
        "messages": null,
        "nextPageToken": null,
        "resultSizeEstimate": 0
    }
    """

    // MARK: - Single Message Response

    static func messageResponse(
        id: String = "msg123",
        subject: String = "Test Subject",
        from: String = "test@example.com",
        snippet: String = "Test snippet"
    ) -> String {
        """
        {
            "id": "\(id)",
            "threadId": "thread\(id)",
            "snippet": "\(snippet)",
            "payload": {
                "headers": [
                    {"name": "Subject", "value": "\(subject)"},
                    {"name": "From", "value": "\(from)"},
                    {"name": "Date", "value": "Mon, 15 Jan 2026 10:00:00 -0800"}
                ],
                "body": {"data": null}
            },
            "internalDate": "\(Int(Date().timeIntervalSince1970 * 1000))"
        }
        """
    }

    static func subscriptionMessage(
        id: String = "sub123",
        merchant: String = "Netflix",
        price: String = "$15.99",
        date: Date = Date()
    ) -> String {
        """
        {
            "id": "\(id)",
            "threadId": "thread\(id)",
            "snippet": "Your \(merchant) subscription of \(price)/mo has been renewed. Thanks for being a member!",
            "payload": {
                "headers": [
                    {"name": "Subject", "value": "Your \(merchant) subscription has renewed"},
                    {"name": "From", "value": "\(merchant) <billing@\(merchant.lowercased()).com>"},
                    {"name": "Date", "value": "Mon, 15 Jan 2026 10:00:00 -0800"},
                    {"name": "List-Unsubscribe", "value": "<mailto:unsubscribe@\(merchant.lowercased()).com>"}
                ],
                "body": {"data": null}
            },
            "internalDate": "\(Int(date.timeIntervalSince1970 * 1000))"
        }
        """
    }

    // MARK: - History Response

    static let historyResponse = """
    {
        "history": [
            {
                "id": "12345",
                "messagesAdded": [
                    {"message": {"id": "newmsg1", "threadId": "thread1"}},
                    {"message": {"id": "newmsg2", "threadId": "thread2"}}
                ]
            }
        ],
        "nextPageToken": null,
        "historyId": "67890"
    }
    """

    static let emptyHistoryResponse = """
    {
        "history": null,
        "nextPageToken": null,
        "historyId": "12345"
    }
    """

    // MARK: - Profile Response

    static let profileResponse = """
    {
        "emailAddress": "test@gmail.com",
        "messagesTotal": 1000,
        "threadsTotal": 500,
        "historyId": "12345"
    }
    """

    // MARK: - Error Responses

    static let rateLimitError = """
    {
        "error": {
            "code": 429,
            "message": "Rate Limit Exceeded",
            "status": "RESOURCE_EXHAUSTED"
        }
    }
    """

    static let unauthorizedError = """
    {
        "error": {
            "code": 401,
            "message": "Invalid Credentials",
            "status": "UNAUTHENTICATED"
        }
    }
    """

    static let historyExpiredError = """
    {
        "error": {
            "code": 404,
            "message": "History ID is invalid or has expired",
            "status": "NOT_FOUND"
        }
    }
    """

    static let serverError = """
    {
        "error": {
            "code": 500,
            "message": "Internal Server Error",
            "status": "INTERNAL"
        }
    }
    """

    // MARK: - Helper Methods

    static func asData(_ json: String) -> Data {
        json.data(using: .utf8)!
    }
}

// MARK: - HTTPURLResponse Helpers

extension GmailMockResponses {

    static func successResponse(url: URL = URL(string: "https://gmail.googleapis.com")!) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    static func rateLimitResponse(
        url: URL = URL(string: "https://gmail.googleapis.com")!,
        retryAfter: String? = nil
    ) -> HTTPURLResponse {
        var headers = ["Content-Type": "application/json"]
        if let retryAfter = retryAfter {
            headers["Retry-After"] = retryAfter
        }
        return HTTPURLResponse(
            url: url,
            statusCode: 429,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    static func unauthorizedResponse(url: URL = URL(string: "https://gmail.googleapis.com")!) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    static func notFoundResponse(url: URL = URL(string: "https://gmail.googleapis.com")!) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    static func serverErrorResponse(url: URL = URL(string: "https://gmail.googleapis.com")!) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
