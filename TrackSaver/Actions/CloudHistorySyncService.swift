import Foundation
import CloudKit

actor CloudHistorySyncService {
    static let shared = CloudHistorySyncService()

    private let container = CKContainer(identifier: "iCloud.DyonisosFergadiotis.TrackSaver")
    private nonisolated static let recordType = "HistoryEntry"
    private var inFlightSyncs: [String: Task<[SharedDefaults.HistoryEntry], Never>] = [:]

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    func syncHistory(for userId: String) async -> [SharedDefaults.HistoryEntry] {
        guard !userId.isEmpty else { return [] }

        if let existingTask = inFlightSyncs[userId] {
            return await existingTask.value
        }

        let task = Task { await performSync(for: userId) }
        inFlightSyncs[userId] = task
        let result = await task.value
        inFlightSyncs[userId] = nil
        return result
    }

    private func performSync(for userId: String) async -> [SharedDefaults.HistoryEntry] {
        let localFallback = SharedDefaults.historyEntriesMergedWithPendingChanges(
            SharedDefaults.loadHistoryEntries(for: userId),
            for: userId
        )

        do {
            try await pushPendingUpserts(for: userId)
            try await pushPendingDeletes(for: userId)

            let remoteEntries = try await fetchRemoteHistory(for: userId)
            let mergedEntries = SharedDefaults.historyEntriesMergedWithPendingChanges(remoteEntries, for: userId)
            SharedDefaults.saveHistoryEntries(mergedEntries, for: userId)
            return mergedEntries
        } catch {
            SharedDefaults.saveHistoryEntries(localFallback, for: userId)
            return localFallback
        }
    }

    private func pushPendingUpserts(for userId: String) async throws {
        let pendingUpserts = SharedDefaults.loadPendingHistoryUpserts(for: userId)
        guard !pendingUpserts.isEmpty else { return }

        var syncedIDs: [UUID] = []
        do {
            for entry in pendingUpserts {
                try await saveRecord(Self.makeRecord(from: entry, userId: userId))
                syncedIDs.append(entry.id)
            }
            SharedDefaults.markPendingHistoryUpsertsSynced(syncedIDs, for: userId)
        } catch {
            SharedDefaults.markPendingHistoryUpsertsSynced(syncedIDs, for: userId)
            throw error
        }
    }

    private func pushPendingDeletes(for userId: String) async throws {
        let pendingDeletes = SharedDefaults.loadPendingHistoryDeletes(for: userId)
        guard !pendingDeletes.isEmpty else { return }

        var syncedIDs: [UUID] = []
        do {
            for entryID in pendingDeletes {
                try await deleteRecord(id: Self.recordID(for: entryID, userId: userId))
                syncedIDs.append(entryID)
            }
            SharedDefaults.markPendingHistoryDeletesSynced(syncedIDs, for: userId)
        } catch {
            SharedDefaults.markPendingHistoryDeletesSynced(syncedIDs, for: userId)
            throw error
        }
    }

    private func fetchRemoteHistory(for userId: String) async throws -> [SharedDefaults.HistoryEntry] {
        var fetchedEntries: [SharedDefaults.HistoryEntry] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page = try await fetchHistoryPage(for: userId, cursor: cursor)
            fetchedEntries.append(contentsOf: page.entries)
            cursor = page.cursor
        } while cursor != nil

        return fetchedEntries
    }

    private func fetchHistoryPage(
        for userId: String,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (entries: [SharedDefaults.HistoryEntry], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(
                    recordType: Self.recordType,
                    predicate: NSPredicate(format: "userId == %@", userId)
                )
                query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                operation = CKQueryOperation(query: query)
            }

            operation.resultsLimit = 200

            let lock = NSLock()
            var entries: [SharedDefaults.HistoryEntry] = []

            operation.recordMatchedBlock = { _, result in
                guard case .success(let record) = result,
                      let entry = Self.makeEntry(from: record) else {
                    return
                }
                lock.lock()
                entries.append(entry)
                lock.unlock()
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    lock.lock()
                    let pageEntries = entries
                    lock.unlock()
                    continuation.resume(returning: (pageEntries, nextCursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func saveRecord(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.save(record) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func deleteRecord(id: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.delete(withRecordID: id) { _, error in
                if let error = error as? CKError, error.code == .unknownItem {
                    continuation.resume(returning: ())
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private nonisolated static func makeRecord(from entry: SharedDefaults.HistoryEntry, userId: String) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: Self.recordID(for: entry.id, userId: userId))
        record["userId"] = userId as CKRecordValue
        record["entryId"] = entry.id.uuidString as CKRecordValue
        record["trackName"] = entry.trackName as CKRecordValue
        record["artistName"] = entry.artistName as CKRecordValue
        if let artworkURL = entry.artworkURL, !artworkURL.isEmpty {
            record["artworkURL"] = artworkURL as CKRecordValue
        } else {
            record["artworkURL"] = nil
        }
        if let trackURI = entry.trackURI, !trackURI.isEmpty {
            record["trackURI"] = trackURI as CKRecordValue
        } else {
            record["trackURI"] = nil
        }
        record["date"] = entry.date as CKRecordValue
        record["status"] = entry.status as CKRecordValue
        if let playlistName = entry.playlistName, !playlistName.isEmpty {
            record["playlistName"] = playlistName as CKRecordValue
        } else {
            record["playlistName"] = nil
        }
        return record
    }

    private nonisolated static func makeEntry(from record: CKRecord) -> SharedDefaults.HistoryEntry? {
        guard let trackName = record["trackName"] as? String,
              let artistName = record["artistName"] as? String,
              let date = record["date"] as? Date,
              let status = record["status"] as? String else {
            return nil
        }

        let recordName = record.recordID.recordName
        let fallbackID = UUID(uuidString: recordName.components(separatedBy: "__").last ?? "")
        let entryID = UUID(uuidString: record["entryId"] as? String ?? "") ?? fallbackID

        guard let entryID else { return nil }

        return SharedDefaults.HistoryEntry(
            id: entryID,
            trackName: trackName,
            artistName: artistName,
            artworkURL: record["artworkURL"] as? String,
            trackURI: record["trackURI"] as? String,
            date: date,
            status: status,
            playlistName: record["playlistName"] as? String
        )
    }

    private nonisolated static func recordID(for entryID: UUID, userId: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(userId)__\(entryID.uuidString)")
    }
}
