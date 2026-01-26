//
//  GmailSyncState.swift
//  subscriptionManager
//
//  Created by Karthik Khatri on 1/24/26.
//

import Foundation

// MARK: - Gmail Sync State

/// Tracks Gmail sync state for incremental synchronization
struct GmailSyncState: Codable {
    /// Gmail history ID from last successful sync (used for incremental sync)
    var lastHistoryId: String?

    /// Date of last full scan (fetched all messages)
    var lastFullScanDate: Date?

    /// Date of last incremental sync (history API)
    var lastIncrementalSyncDate: Date?

    /// Set of message IDs we've already processed
    var processedMessageIds: Set<String>

    /// Number of subscriptions found in last scan
    var lastSubscriptionCount: Int

    /// Total emails scanned in last scan
    var lastEmailsScanned: Int

    init(
        lastHistoryId: String? = nil,
        lastFullScanDate: Date? = nil,
        lastIncrementalSyncDate: Date? = nil,
        processedMessageIds: Set<String> = [],
        lastSubscriptionCount: Int = 0,
        lastEmailsScanned: Int = 0
    ) {
        self.lastHistoryId = lastHistoryId
        self.lastFullScanDate = lastFullScanDate
        self.lastIncrementalSyncDate = lastIncrementalSyncDate
        self.processedMessageIds = processedMessageIds
        self.lastSubscriptionCount = lastSubscriptionCount
        self.lastEmailsScanned = lastEmailsScanned
    }

    /// Check if we have a valid history ID for incremental sync
    var canPerformIncrementalSync: Bool {
        lastHistoryId != nil
    }

    /// Check if the sync state is fresh (synced recently)
    func isFresh(within hours: Int = 24) -> Bool {
        guard let lastSync = lastIncrementalSyncDate ?? lastFullScanDate else {
            return false
        }
        let hoursSinceSync = Calendar.current.dateComponents(
            [.hour],
            from: lastSync,
            to: Date()
        ).hour ?? Int.max

        return hoursSinceSync < hours
    }
}

// MARK: - Sync State Manager

/// Manages persistent storage of Gmail sync state
actor GmailSyncStateManager {

    // MARK: - Singleton

    static let shared = GmailSyncStateManager()

    // MARK: - Configuration

    private let stateFileName = "gmail_sync_state.json"

    // MARK: - Properties

    private var state: GmailSyncState?
    private var isLoaded = false

    private var stateFileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(stateFileName)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Get the current sync state (loads from disk if needed)
    func getState() async -> GmailSyncState {
        await loadIfNeeded()
        return state ?? GmailSyncState()
    }

    /// Update the sync state
    func updateState(_ newState: GmailSyncState) async {
        state = newState
        await save()
    }

    /// Update history ID after successful sync
    func updateHistoryId(_ historyId: String) async {
        await loadIfNeeded()
        var currentState = state ?? GmailSyncState()
        currentState.lastHistoryId = historyId
        currentState.lastIncrementalSyncDate = Date()
        state = currentState
        await save()
    }

    /// Mark a full scan as complete
    func markFullScanComplete(
        historyId: String?,
        processedIds: Set<String>,
        subscriptionCount: Int,
        emailsScanned: Int
    ) async {
        await loadIfNeeded()
        var currentState = state ?? GmailSyncState()
        currentState.lastHistoryId = historyId
        currentState.lastFullScanDate = Date()
        currentState.lastIncrementalSyncDate = Date()
        currentState.processedMessageIds = processedIds
        currentState.lastSubscriptionCount = subscriptionCount
        currentState.lastEmailsScanned = emailsScanned
        state = currentState
        await save()
    }

    /// Mark an incremental sync as complete
    func markIncrementalSyncComplete(
        historyId: String,
        newMessageIds: Set<String>,
        subscriptionCount: Int
    ) async {
        await loadIfNeeded()
        var currentState = state ?? GmailSyncState()
        currentState.lastHistoryId = historyId
        currentState.lastIncrementalSyncDate = Date()
        currentState.processedMessageIds.formUnion(newMessageIds)
        currentState.lastSubscriptionCount = subscriptionCount
        state = currentState
        await save()
    }

    /// Check if a message ID has already been processed
    func isMessageProcessed(_ messageId: String) async -> Bool {
        await loadIfNeeded()
        return state?.processedMessageIds.contains(messageId) ?? false
    }

    /// Add a set of processed message IDs
    func addProcessedMessageIds(_ ids: Set<String>) async {
        await loadIfNeeded()
        var currentState = state ?? GmailSyncState()
        currentState.processedMessageIds.formUnion(ids)
        state = currentState
        await save()
    }

    /// Clear the sync state (forces full rescan)
    func clearState() async {
        state = GmailSyncState()
        try? FileManager.default.removeItem(at: stateFileURL)
    }

    /// Get last history ID (nil if none or expired)
    func getLastHistoryId() async -> String? {
        await loadIfNeeded()
        return state?.lastHistoryId
    }

    // MARK: - Private Methods

    private func loadIfNeeded() async {
        guard !isLoaded else { return }

        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            state = GmailSyncState()
            isLoaded = true
            return
        }

        do {
            let data = try Data(contentsOf: stateFileURL)
            state = try JSONDecoder().decode(GmailSyncState.self, from: data)
        } catch {
            state = GmailSyncState()
        }

        isLoaded = true
    }

    private func save() async {
        guard let state = state else { return }

        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            // Silent failure - sync state is recoverable
        }
    }
}

// MARK: - Incremental Sync Result

/// Result from an incremental sync using Gmail History API
struct IncrementalSyncResult {
    /// New message IDs added since last sync
    let newMessageIds: [String]

    /// Updated history ID for next sync
    let latestHistoryId: String

    /// Whether the history ID was expired (requires full scan)
    let historyExpired: Bool

    /// Number of history records processed
    let historyRecordsProcessed: Int

    init(
        newMessageIds: [String] = [],
        latestHistoryId: String = "",
        historyExpired: Bool = false,
        historyRecordsProcessed: Int = 0
    ) {
        self.newMessageIds = newMessageIds
        self.latestHistoryId = latestHistoryId
        self.historyExpired = historyExpired
        self.historyRecordsProcessed = historyRecordsProcessed
    }

    /// Create a result indicating history has expired
    static var expired: IncrementalSyncResult {
        IncrementalSyncResult(historyExpired: true)
    }
}
