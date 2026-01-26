//
//  GmailMessageCache.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/24/26.
//

import Foundation

// MARK: - Cached Message Wrapper

/// Wrapper for NSCache compatibility (requires class type)
final class CachedMessage: NSObject {
    let message: GmailMessage
    let cachedAt: Date

    init(message: GmailMessage, cachedAt: Date = Date()) {
        self.message = message
        self.cachedAt = cachedAt
    }
}

// MARK: - Gmail Message Cache

/// Two-tier caching system for Gmail messages
/// - In-memory: NSCache for fast lookups during session (auto-evicts under memory pressure)
/// - Disk: File-based cache for message metadata (survives app restart)
actor GmailMessageCache {

    // MARK: - Singleton

    static let shared = GmailMessageCache()

    // MARK: - Configuration

    private let maxMemoryCacheCount = 1000
    private let maxDiskCacheAgeDays = 30
    private let cacheFileName = "gmail_message_cache.json"

    // MARK: - In-Memory Cache

    private let memoryCache: NSCache<NSString, CachedMessage> = {
        let cache = NSCache<NSString, CachedMessage>()
        cache.countLimit = 1000
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        return cache
    }()

    // MARK: - Disk Cache

    private var diskCache: [String: DiskCachedMessage] = [:]
    private var isDiskCacheLoaded = false

    private var cacheDirectory: URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("GmailCache")
    }

    private var cacheFileURL: URL {
        cacheDirectory.appendingPathComponent(cacheFileName)
    }

    // MARK: - Initialization

    private init() {
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Get a single message from cache (checks memory first, then disk)
    func get(_ id: String) async -> GmailMessage? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: id as NSString) {
            return cached.message
        }

        // Check disk cache
        await loadDiskCacheIfNeeded()
        if let diskCached = diskCache[id] {
            // Promote to memory cache
            let cached = CachedMessage(message: diskCached.toGmailMessage(), cachedAt: diskCached.cachedAt)
            memoryCache.setObject(cached, forKey: id as NSString)
            return diskCached.toGmailMessage()
        }

        return nil
    }

    /// Store a single message in cache (both memory and disk)
    func set(_ message: GmailMessage) async {
        // Store in memory cache
        let cached = CachedMessage(message: message)
        memoryCache.setObject(cached, forKey: message.id as NSString)

        // Store in disk cache
        await loadDiskCacheIfNeeded()
        diskCache[message.id] = DiskCachedMessage(from: message)

        // Persist to disk (debounced in real usage)
        await saveDiskCache()
    }

    /// Get multiple messages from cache, returning cached and missing IDs
    func getBatch(_ ids: [String]) async -> (cached: [GmailMessage], missing: [String]) {
        var cached: [GmailMessage] = []
        var missing: [String] = []

        await loadDiskCacheIfNeeded()

        for id in ids {
            if let message = await get(id) {
                cached.append(message)
            } else {
                missing.append(id)
            }
        }

        return (cached, missing)
    }

    /// Store multiple messages in cache
    func setBatch(_ messages: [GmailMessage]) async {
        for message in messages {
            let cached = CachedMessage(message: message)
            memoryCache.setObject(cached, forKey: message.id as NSString)
            diskCache[message.id] = DiskCachedMessage(from: message)
        }

        await saveDiskCache()
    }

    /// Check if a message ID exists in cache
    func contains(_ id: String) async -> Bool {
        if memoryCache.object(forKey: id as NSString) != nil {
            return true
        }

        await loadDiskCacheIfNeeded()
        return diskCache[id] != nil
    }

    /// Get all cached message IDs
    func getAllCachedIds() async -> Set<String> {
        await loadDiskCacheIfNeeded()
        return Set(diskCache.keys)
    }

    /// Clear all caches
    func clear() async {
        memoryCache.removeAllObjects()
        diskCache.removeAll()
        try? FileManager.default.removeItem(at: cacheFileURL)
    }

    /// Remove expired entries from disk cache
    func pruneExpiredEntries() async {
        await loadDiskCacheIfNeeded()

        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -maxDiskCacheAgeDays,
            to: Date()
        ) ?? Date()

        let originalCount = diskCache.count
        diskCache = diskCache.filter { $0.value.cachedAt > cutoffDate }

        if diskCache.count < originalCount {
            await saveDiskCache()
        }
    }

    /// Get cache statistics
    func getStats() async -> CacheStats {
        await loadDiskCacheIfNeeded()
        return CacheStats(
            diskCacheCount: diskCache.count,
            oldestEntry: diskCache.values.map { $0.cachedAt }.min(),
            newestEntry: diskCache.values.map { $0.cachedAt }.max()
        )
    }

    // MARK: - Private Methods

    private func loadDiskCacheIfNeeded() async {
        guard !isDiskCacheLoaded else { return }

        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            isDiskCacheLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoded = try JSONDecoder().decode([String: DiskCachedMessage].self, from: data)
            diskCache = decoded
        } catch {
            // If loading fails, start fresh
            diskCache = [:]
        }

        isDiskCacheLoaded = true
    }

    private func saveDiskCache() async {
        do {
            let data = try JSONEncoder().encode(diskCache)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            // Silent failure - cache is non-critical
        }
    }
}

// MARK: - Disk Cache Model

/// Lightweight model for disk persistence (stores only essential metadata)
struct DiskCachedMessage: Codable {
    let id: String
    let threadId: String
    let snippet: String
    let subject: String
    let from: String
    let internalDate: String?
    let hasUnsubscribeHeader: Bool
    let cachedAt: Date

    init(from message: GmailMessage, cachedAt: Date = Date()) {
        self.id = message.id
        self.threadId = message.threadId
        self.snippet = message.snippet
        self.subject = message.subject
        self.from = message.from
        self.internalDate = message.internalDate
        self.hasUnsubscribeHeader = message.hasUnsubscribeHeader
        self.cachedAt = cachedAt
    }

    func toGmailMessage() -> GmailMessage {
        // Reconstruct minimal GmailMessage from cached data
        let headers = [
            MessageHeader(name: "Subject", value: subject),
            MessageHeader(name: "From", value: from)
        ]

        var allHeaders = headers
        if hasUnsubscribeHeader {
            allHeaders.append(MessageHeader(name: "List-Unsubscribe", value: "cached"))
        }

        let payload = MessagePayload(headers: allHeaders, body: nil)

        return GmailMessage(
            id: id,
            threadId: threadId,
            snippet: snippet,
            payload: payload,
            internalDate: internalDate
        )
    }
}

// MARK: - Cache Statistics

struct CacheStats {
    let diskCacheCount: Int
    let oldestEntry: Date?
    let newestEntry: Date?
}
