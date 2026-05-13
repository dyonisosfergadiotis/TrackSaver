import Foundation

struct SharedSelectedPlaylistSnapshot: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String
    let artworkURL: String

    nonisolated var isEmpty: Bool {
        id.isEmpty && name.isEmpty && description.isEmpty && artworkURL.isEmpty
    }
}

enum SharedDefaults {
    nonisolated static let suiteName = "group.dyonisosfergadiotis.tracksaver"
    nonisolated(unsafe) static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    nonisolated static let historyDidChangeNotification = Notification.Name("SharedDefaults.historyDidChange")
    nonisolated static let historyRefreshRequestedNotification = Notification.Name("SharedDefaults.historyRefreshRequested")
    nonisolated static let historyDidChangeUserIdKey = "userId"

    private nonisolated static let defaultPlaylistKey = "DefaultPlaylistId"
    private nonisolated static let shortcutPlaylistPrefix = "ShortcutPlaylistId."
    private nonisolated static let playlistNamesByIdKey = "PlaylistNamesByIdJSON"
    private nonisolated static let selectedPlaylistSnapshotKey = "SelectedPlaylistSnapshotJSON"
    private nonisolated static let configurationUpdatedAtKey = "ConfigurationUpdatedAt"
    private nonisolated static let historyPrefix = "LocalHistoryJSON."
    private nonisolated static let historyPendingUpsertsPrefix = "HistoryPendingUpserts."
    private nonisolated static let historyPendingDeletesPrefix = "HistoryPendingDeletes."
    private nonisolated static let lastHistoryUserIdKey = "LastHistoryUserId"
    private nonisolated static let spotifyLoggedInKey = "SpotifyLoggedIn"
    private nonisolated static let accountUserIdKey = "AccountUserId"
    private nonisolated static let accountDisplayNameKey = "AccountDisplayName"
    private nonisolated static let accountAvatarURLKey = "AccountAvatarURL"
    private nonisolated static let accountUpdatedAtKey = "AccountUpdatedAt"
    private nonisolated static let iosAppLaunchedKey = "IOSAppLaunched"
    private nonisolated static let iosLaunchRequestedByMacKey = "IOSLaunchRequestedByMac"
    private nonisolated static let iosBootstrapUpdatedAtKey = "IOSBootstrapUpdatedAt"
    private nonisolated static let legacyHistoryKey = "LocalHistoryJSON"
    nonisolated static let shortcutSlots = [1, 2, 3]
    private nonisolated static let maxHistoryItems = 250

    struct AccountSnapshot: Codable, Equatable, Sendable {
        let spotifyLoggedIn: Bool
        let userId: String
        let displayName: String
        let avatarURL: String
        let updatedAt: Date

        nonisolated static func loggedOut(updatedAt: Date = Date()) -> Self {
            .init(
                spotifyLoggedIn: false,
                userId: "",
                displayName: "",
                avatarURL: "",
                updatedAt: updatedAt
            )
        }

        nonisolated var isEmpty: Bool {
            !spotifyLoggedIn &&
            userId.isEmpty &&
            displayName.isEmpty &&
            avatarURL.isEmpty &&
            updatedAt == .distantPast
        }
    }

    struct HistoryEntry: Codable, Equatable, Sendable {
        let id: UUID
        let trackName: String
        let artistName: String
        let artworkURL: String?
        let trackURI: String?
        let date: Date
        let status: String
        let playlistName: String?

        nonisolated init(
            id: UUID = UUID(),
            trackName: String,
            artistName: String,
            artworkURL: String?,
            trackURI: String? = nil,
            date: Date = Date(),
            status: String,
            playlistName: String?
        ) {
            self.id = id
            self.trackName = trackName
            self.artistName = artistName
            self.artworkURL = artworkURL
            self.trackURI = trackURI
            self.date = date
            self.status = status
            self.playlistName = playlistName
        }
    }

    struct ConfigurationSnapshot: Codable, Equatable, Sendable {
        let selectedPlaylist: SharedSelectedPlaylistSnapshot?
        let defaultPlaylistId: String
        let shortcutPlaylistIds: [Int: String]
        let playlistNamesById: [String: String]
        let updatedAt: Date

        nonisolated static func empty(updatedAt: Date = .distantPast) -> Self {
            .init(
                selectedPlaylist: nil,
                defaultPlaylistId: "",
                shortcutPlaylistIds: [:],
                playlistNamesById: [:],
                updatedAt: updatedAt
            )
        }

        nonisolated var isEmpty: Bool {
            selectedPlaylist == nil &&
            defaultPlaylistId.isEmpty &&
            shortcutPlaylistIds.isEmpty &&
            playlistNamesById.isEmpty &&
            updatedAt == .distantPast
        }
    }

    struct IOSBootstrapSnapshot: Codable, Equatable, Sendable {
        let iosAppLaunched: Bool
        let iosLaunchRequestedByMac: Bool
        let updatedAt: Date

        nonisolated static func initial(updatedAt: Date = .distantPast) -> Self {
            .init(
                iosAppLaunched: false,
                iosLaunchRequestedByMac: false,
                updatedAt: updatedAt
            )
        }

        nonisolated var isEmpty: Bool {
            !iosAppLaunched &&
            !iosLaunchRequestedByMac &&
            updatedAt == .distantPast
        }
    }

    nonisolated static func migrateDefaultPlaylistIdIfNeeded() {
        let sharedValue = store.string(forKey: defaultPlaylistKey) ?? ""
        if !sharedValue.isEmpty { return }
        let legacyValue = UserDefaults.standard.string(forKey: defaultPlaylistKey) ?? ""
        guard !legacyValue.isEmpty else { return }
        setStoreValue(legacyValue, forKey: defaultPlaylistKey)
    }

    nonisolated static func migrateLegacyAccountIfNeeded() {
        let sharedSnapshot = loadAccountSnapshot()
        if !sharedSnapshot.isEmpty {
            if sharedSnapshot.updatedAt == .distantPast {
                saveAccountSnapshot(
                    AccountSnapshot(
                        spotifyLoggedIn: sharedSnapshot.spotifyLoggedIn,
                        userId: sharedSnapshot.userId,
                        displayName: sharedSnapshot.displayName,
                        avatarURL: sharedSnapshot.avatarURL,
                        updatedAt: Date()
                    )
                )
            }
            return
        }

        let standard = UserDefaults.standard
        let standardLoggedIn = standard.object(forKey: spotifyLoggedInKey) as? Bool
        let standardUserId = standard.string(forKey: accountUserIdKey) ?? ""
        let standardDisplayName = standard.string(forKey: accountDisplayNameKey) ?? ""
        let standardAvatarURL = standard.string(forKey: accountAvatarURLKey) ?? ""

        guard standardLoggedIn != nil ||
                !standardUserId.isEmpty ||
                !standardDisplayName.isEmpty ||
                !standardAvatarURL.isEmpty else {
            return
        }

        saveAccountSnapshot(
            AccountSnapshot(
                spotifyLoggedIn: standardLoggedIn ?? !standardUserId.isEmpty,
                userId: standardUserId,
                displayName: standardDisplayName,
                avatarURL: standardAvatarURL,
                updatedAt: Date()
            )
        )

        standard.removeObject(forKey: spotifyLoggedInKey)
        standard.removeObject(forKey: accountUserIdKey)
        standard.removeObject(forKey: accountDisplayNameKey)
        standard.removeObject(forKey: accountAvatarURLKey)
    }

    nonisolated static func loadAccountSnapshot() -> AccountSnapshot {
        let updatedAt: Date
        if let rawUpdatedAt = store.object(forKey: accountUpdatedAtKey) as? Double {
            updatedAt = Date(timeIntervalSince1970: rawUpdatedAt)
        } else {
            updatedAt = .distantPast
        }

        return AccountSnapshot(
            spotifyLoggedIn: (store.object(forKey: spotifyLoggedInKey) as? Bool) ?? false,
            userId: store.string(forKey: accountUserIdKey) ?? "",
            displayName: store.string(forKey: accountDisplayNameKey) ?? "",
            avatarURL: store.string(forKey: accountAvatarURLKey) ?? "",
            updatedAt: updatedAt
        )
    }

    nonisolated static func saveAccountSnapshot(_ snapshot: AccountSnapshot) {
        setStoreValue(snapshot.spotifyLoggedIn, forKey: spotifyLoggedInKey)
        setOrRemove(snapshot.userId, forKey: accountUserIdKey)
        setOrRemove(snapshot.displayName, forKey: accountDisplayNameKey)
        setOrRemove(snapshot.avatarURL, forKey: accountAvatarURLKey)
        setStoreValue(snapshot.updatedAt.timeIntervalSince1970, forKey: accountUpdatedAtKey)
    }

    nonisolated static func updateLoggedInAccount(
        userId: String,
        displayName: String,
        avatarURL: String,
        updatedAt: Date = Date()
    ) {
        saveAccountSnapshot(
            AccountSnapshot(
                spotifyLoggedIn: true,
                userId: userId,
                displayName: displayName,
                avatarURL: avatarURL,
                updatedAt: updatedAt
            )
        )
    }

    nonisolated static func clearAccount(updatedAt: Date = Date()) {
        saveAccountSnapshot(.loggedOut(updatedAt: updatedAt))
    }

    nonisolated static func isSpotifyLoggedIn() -> Bool {
        loadAccountSnapshot().spotifyLoggedIn
    }

    nonisolated static func accountUserId() -> String {
        loadAccountSnapshot().userId
    }

    nonisolated static func loadConfigurationSnapshot() -> ConfigurationSnapshot {
        let updatedAt: Date
        if let rawUpdatedAt = store.object(forKey: configurationUpdatedAtKey) as? Double {
            updatedAt = Date(timeIntervalSince1970: rawUpdatedAt)
        } else {
            updatedAt = .distantPast
        }

        return configurationSnapshot(updatedAt: updatedAt)
    }

    nonisolated static func currentConfigurationSnapshot(updatedAt: Date = Date()) -> ConfigurationSnapshot {
        configurationSnapshot(updatedAt: updatedAt)
    }

    nonisolated static func saveConfigurationSnapshot(_ snapshot: ConfigurationSnapshot) {
        saveSelectedPlaylistSnapshot(snapshot.selectedPlaylist)

        let trimmedDefaultPlaylistId = snapshot.defaultPlaylistId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDefaultPlaylistId.isEmpty {
            removeStoreValue(forKey: defaultPlaylistKey)
        } else {
            setStoreValue(trimmedDefaultPlaylistId, forKey: defaultPlaylistKey)
        }

        for slot in shortcutSlots {
            let trimmedPlaylistId = (snapshot.shortcutPlaylistIds[slot] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPlaylistId.isEmpty {
                removeStoreValue(forKey: shortcutPlaylistStorageKey(for: slot))
            } else {
                setStoreValue(trimmedPlaylistId, forKey: shortcutPlaylistStorageKey(for: slot))
            }
        }

        savePlaylistNamesById(snapshot.playlistNamesById)
        setStoreValue(snapshot.updatedAt.timeIntervalSince1970, forKey: configurationUpdatedAtKey)
    }

    nonisolated static func loadIOSBootstrapSnapshot() -> IOSBootstrapSnapshot {
        let updatedAt: Date
        if let rawUpdatedAt = store.object(forKey: iosBootstrapUpdatedAtKey) as? Double {
            updatedAt = Date(timeIntervalSince1970: rawUpdatedAt)
        } else {
            updatedAt = .distantPast
        }

        return IOSBootstrapSnapshot(
            iosAppLaunched: (store.object(forKey: iosAppLaunchedKey) as? Bool) ?? false,
            iosLaunchRequestedByMac: (store.object(forKey: iosLaunchRequestedByMacKey) as? Bool) ?? false,
            updatedAt: updatedAt
        )
    }

    nonisolated static func saveIOSBootstrapSnapshot(_ snapshot: IOSBootstrapSnapshot) {
        setStoreValue(snapshot.iosAppLaunched, forKey: iosAppLaunchedKey)
        setStoreValue(snapshot.iosLaunchRequestedByMac, forKey: iosLaunchRequestedByMacKey)
        setStoreValue(snapshot.updatedAt.timeIntervalSince1970, forKey: iosBootstrapUpdatedAtKey)
    }

    nonisolated static func defaultPlaylistId() -> String {
        store.string(forKey: defaultPlaylistKey) ?? ""
    }

    nonisolated static func selectedPlaylistSnapshot() -> SharedSelectedPlaylistSnapshot? {
        guard let raw = store.dictionary(forKey: selectedPlaylistSnapshotKey) as? [String: String] else { return nil }
        let snapshot = SharedSelectedPlaylistSnapshot(
            id: raw["id"] ?? "",
            name: raw["name"] ?? "",
            description: raw["description"] ?? "",
            artworkURL: raw["artworkURL"] ?? ""
        )
        return snapshot.isEmpty ? nil : snapshot
    }

    nonisolated static func cacheSelectedPlaylist(
        id: String,
        name: String,
        description: String?,
        artworkURL: String?
    ) {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            saveSelectedPlaylistSnapshot(nil)
            return
        }

        let snapshot = SharedSelectedPlaylistSnapshot(
            id: trimmedId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: (description ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            artworkURL: (artworkURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
        saveSelectedPlaylistSnapshot(snapshot)

        if !snapshot.name.isEmpty {
            cachePlaylistName(snapshot.name, for: snapshot.id)
        }
    }

    nonisolated static func playlistName(for playlistId: String) -> String? {
        let trimmedId = playlistId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return nil }
        let cachedName = loadPlaylistNamesById()[trimmedId]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cachedName, !cachedName.isEmpty else { return nil }
        return cachedName
    }

    nonisolated static func cachePlaylistName(_ playlistName: String?, for playlistId: String) {
        let trimmedId = playlistId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }

        let trimmedName = (playlistName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var cachedNames = loadPlaylistNamesById()

        if trimmedName.isEmpty {
            cachedNames.removeValue(forKey: trimmedId)
        } else {
            cachedNames[trimmedId] = trimmedName
        }

        savePlaylistNamesById(cachedNames)
    }

    nonisolated static func cachePlaylistNames(_ playlistNamesById: [String: String]) {
        guard !playlistNamesById.isEmpty else { return }

        var cachedNames = loadPlaylistNamesById()
        for (playlistId, playlistName) in playlistNamesById {
            let trimmedId = playlistId.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty, !trimmedName.isEmpty else { continue }
            cachedNames[trimmedId] = trimmedName
        }

        savePlaylistNamesById(cachedNames)
    }

    nonisolated static func configuredShortcutPlaylistId(for slot: Int) -> String {
        guard shortcutSlots.contains(slot) else { return "" }
        return store.string(forKey: shortcutPlaylistStorageKey(for: slot)) ?? ""
    }

    nonisolated static func shortcutPlaylistId(for slot: Int) -> String {
        let configured = configuredShortcutPlaylistId(for: slot)
        if !configured.isEmpty {
            return configured
        }
        return defaultPlaylistId()
    }

    nonisolated static func setShortcutPlaylistId(_ playlistId: String, for slot: Int) {
        guard shortcutSlots.contains(slot) else { return }
        let trimmed = playlistId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeStoreValue(forKey: shortcutPlaylistStorageKey(for: slot))
            return
        }
        setStoreValue(trimmed, forKey: shortcutPlaylistStorageKey(for: slot))
    }

    nonisolated static func clearShortcutPlaylistId(for slot: Int) {
        guard shortcutSlots.contains(slot) else { return }
        removeStoreValue(forKey: shortcutPlaylistStorageKey(for: slot))
    }

    nonisolated static func resolvedShortcutPlaylistId(for slot: Int?) -> String {
        if let slot {
            return shortcutPlaylistId(for: slot)
        }
        return shortcutPlaylistId(for: shortcutSlotForCurrentSegment())
    }

    nonisolated static func hasAnyConfiguredShortcutPlaylist() -> Bool {
        if !defaultPlaylistId().isEmpty {
            return true
        }
        for slot in shortcutSlots where !configuredShortcutPlaylistId(for: slot).isEmpty {
            return true
        }
        return false
    }

    // 3x8h split for Schicht-Shortcuts: 06-14, 14-22, 22-06
    nonisolated static func shortcutSlotForCurrentSegment(date: Date = Date(), calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 6..<14:
            return 1
        case 14..<22:
            return 2
        default:
            return 3
        }
    }

    nonisolated static func historyKey(for userId: String) -> String {
        "\(historyPrefix)\(userId)"
    }

    nonisolated static func loadHistoryJSON(for userId: String) -> String {
        store.string(forKey: historyKey(for: userId)) ?? ""
    }

    nonisolated static func saveHistoryJSON(_ json: String, for userId: String) {
        rememberHistoryUserId(userId)
        setStoreValue(json, forKey: historyKey(for: userId))
        postHistoryDidChange(for: userId)
    }

    nonisolated static func loadHistoryEntries(for userId: String) -> [HistoryEntry] {
        decodeHistoryEntries(from: loadHistoryJSON(for: userId))
    }

    nonisolated static func saveHistoryEntries(_ entries: [HistoryEntry], for userId: String) {
        rememberHistoryUserId(userId)
        let normalized = normalizeHistoryEntries(entries)
        guard !normalized.isEmpty else {
            removeStoreValue(forKey: historyKey(for: userId))
            postHistoryDidChange(for: userId)
            return
        }
        guard let data = try? makeHistoryEncoder().encode(normalized),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        saveHistoryJSON(json, for: userId)
    }

    nonisolated static func appendHistoryEntry(_ entry: HistoryEntry, for userId: String) {
        stageHistoryEntry(entry, for: userId)
    }

    nonisolated static func stageHistoryEntry(_ entry: HistoryEntry, for userId: String) {
        guard !userId.isEmpty else { return }
        let mergedLocal = normalizeHistoryEntries(loadHistoryEntries(for: userId) + [entry])
        saveHistoryEntries(mergedLocal, for: userId)

        var pendingUpserts = normalizeHistoryEntries(loadPendingHistoryUpserts(for: userId) + [entry], limit: nil)
        pendingUpserts = normalizeHistoryEntries(pendingUpserts, limit: maxHistoryItems)
        savePendingHistoryUpserts(pendingUpserts, for: userId)

        var pendingDeletes = Set(loadPendingHistoryDeletes(for: userId))
        pendingDeletes.remove(entry.id)
        savePendingHistoryDeletes(Array(pendingDeletes), for: userId)
    }

    nonisolated static func stageHistoryDeletion(_ entryId: UUID, for userId: String) {
        guard !userId.isEmpty else { return }
        let remainingEntries = loadHistoryEntries(for: userId).filter { $0.id != entryId }
        saveHistoryEntries(remainingEntries, for: userId)

        let remainingUpserts = loadPendingHistoryUpserts(for: userId).filter { $0.id != entryId }
        savePendingHistoryUpserts(remainingUpserts, for: userId)

        var pendingDeletes = Set(loadPendingHistoryDeletes(for: userId))
        pendingDeletes.insert(entryId)
        savePendingHistoryDeletes(Array(pendingDeletes), for: userId)
    }

    nonisolated static func clearHistory(for userId: String) {
        stageClearHistory(for: userId)
    }

    nonisolated static func stageClearHistory(for userId: String) {
        guard !userId.isEmpty else { return }
        let existingIDs = loadHistoryEntries(for: userId).map(\.id)
        let stagedDeletes = Set(loadPendingHistoryDeletes(for: userId)).union(existingIDs)
        savePendingHistoryDeletes(Array(stagedDeletes), for: userId)
        savePendingHistoryUpserts([], for: userId)
        saveHistoryEntries([], for: userId)
    }

    nonisolated static func loadPendingHistoryUpserts(for userId: String) -> [HistoryEntry] {
        decodeHistoryEntries(from: store.string(forKey: pendingHistoryUpsertsKey(for: userId)) ?? "")
    }

    nonisolated static func loadPendingHistoryDeletes(for userId: String) -> [UUID] {
        let raw = store.string(forKey: pendingHistoryDeletesKey(for: userId)) ?? ""
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        return (try? makeHistoryDecoder().decode([UUID].self, from: data)) ?? []
    }

    nonisolated static func markPendingHistoryUpsertsSynced(_ ids: [UUID], for userId: String) {
        guard !ids.isEmpty else { return }
        let synced = Set(ids)
        let remaining = loadPendingHistoryUpserts(for: userId).filter { !synced.contains($0.id) }
        savePendingHistoryUpserts(remaining, for: userId)
    }

    nonisolated static func markPendingHistoryDeletesSynced(_ ids: [UUID], for userId: String) {
        guard !ids.isEmpty else { return }
        let synced = Set(ids)
        let remaining = loadPendingHistoryDeletes(for: userId).filter { !synced.contains($0) }
        savePendingHistoryDeletes(remaining, for: userId)
    }

    nonisolated static func historyEntriesMergedWithPendingChanges(_ remoteEntries: [HistoryEntry], for userId: String) -> [HistoryEntry] {
        var mergedByID = Dictionary(uniqueKeysWithValues: normalizeHistoryEntries(remoteEntries, limit: nil).map { ($0.id, $0) })

        for entry in loadPendingHistoryUpserts(for: userId) {
            mergedByID[entry.id] = entry
        }

        let pendingDeletes = Set(loadPendingHistoryDeletes(for: userId))
        for entryId in pendingDeletes {
            mergedByID.removeValue(forKey: entryId)
        }

        return normalizeHistoryEntries(Array(mergedByID.values))
    }

    nonisolated static func preferredHistoryUserId(fallbackUserId: String? = nil) -> String {
        let fallbackUserId = normalizeHistoryUserId(fallbackUserId ?? "")
        if !fallbackUserId.isEmpty {
            return fallbackUserId
        }

        let accountUserId = normalizeHistoryUserId(accountUserId())
        if !accountUserId.isEmpty {
            return accountUserId
        }

        let lastKnownHistoryUserId = normalizeHistoryUserId(store.string(forKey: lastHistoryUserIdKey) ?? "")
        if hasCachedHistory(for: lastKnownHistoryUserId) {
            return lastKnownHistoryUserId
        }

        return discoveredHistoryUserIds().first ?? ""
    }

    nonisolated static func requestHistoryRefresh() {
        postNotification(name: historyRefreshRequestedNotification)
    }

    nonisolated static func migrateLegacyHistoryIfNeeded(for userId: String) {
        let targetKey = historyKey(for: userId)
        let existing = store.string(forKey: targetKey) ?? ""
        if !existing.isEmpty { return }

        let sharedLegacy = store.string(forKey: legacyHistoryKey) ?? ""
        if !sharedLegacy.isEmpty {
            rememberHistoryUserId(userId)
            setStoreValue(sharedLegacy, forKey: targetKey)
            removeStoreValue(forKey: legacyHistoryKey)
            return
        }

        let standardLegacy = UserDefaults.standard.string(forKey: legacyHistoryKey) ?? ""
        guard !standardLegacy.isEmpty else { return }
        rememberHistoryUserId(userId)
        setStoreValue(standardLegacy, forKey: targetKey)
        UserDefaults.standard.removeObject(forKey: legacyHistoryKey)
    }

    private nonisolated static func normalizeHistoryEntries(_ entries: [HistoryEntry], limit: Int? = maxHistoryItems) -> [HistoryEntry] {
        var deduplicated: [UUID: HistoryEntry] = [:]

        for entry in entries {
            if let existing = deduplicated[entry.id], existing.date >= entry.date {
                continue
            }
            deduplicated[entry.id] = entry
        }

        let sorted = deduplicated.values.sorted {
            if $0.date == $1.date {
                return $0.id.uuidString > $1.id.uuidString
            }
            return $0.date > $1.date
        }

        if let limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    private nonisolated static func decodeHistoryEntries(from raw: String) -> [HistoryEntry] {
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        return (try? makeHistoryDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }

    private nonisolated static func savePendingHistoryUpserts(_ entries: [HistoryEntry], for userId: String) {
        let normalized = normalizeHistoryEntries(entries, limit: nil)
        let key = pendingHistoryUpsertsKey(for: userId)
        guard !normalized.isEmpty else {
            removeStoreValue(forKey: key)
            return
        }
        guard let data = try? makeHistoryEncoder().encode(normalized),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        setStoreValue(json, forKey: key)
    }

    private nonisolated static func savePendingHistoryDeletes(_ ids: [UUID], for userId: String) {
        let normalized = Array(Set(ids)).sorted { $0.uuidString > $1.uuidString }
        let key = pendingHistoryDeletesKey(for: userId)
        guard !normalized.isEmpty else {
            removeStoreValue(forKey: key)
            return
        }
        guard let data = try? makeHistoryEncoder().encode(normalized),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        setStoreValue(json, forKey: key)
    }

    private nonisolated static func pendingHistoryUpsertsKey(for userId: String) -> String {
        "\(historyPendingUpsertsPrefix)\(userId)"
    }

    private nonisolated static func pendingHistoryDeletesKey(for userId: String) -> String {
        "\(historyPendingDeletesPrefix)\(userId)"
    }

    private nonisolated static func normalizeHistoryUserId(_ userId: String) -> String {
        userId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func rememberHistoryUserId(_ userId: String) {
        let normalizedUserId = normalizeHistoryUserId(userId)
        guard !normalizedUserId.isEmpty else { return }
        setStoreValue(normalizedUserId, forKey: lastHistoryUserIdKey)
    }

    private nonisolated static func hasCachedHistory(for userId: String) -> Bool {
        let normalizedUserId = normalizeHistoryUserId(userId)
        guard !normalizedUserId.isEmpty else { return false }
        return !(store.string(forKey: historyKey(for: normalizedUserId)) ?? "").isEmpty ||
            !(store.string(forKey: pendingHistoryUpsertsKey(for: normalizedUserId)) ?? "").isEmpty ||
            !(store.string(forKey: pendingHistoryDeletesKey(for: normalizedUserId)) ?? "").isEmpty
    }

    private nonisolated static func discoveredHistoryUserIds() -> [String] {
        let knownPrefixes = [historyPrefix, historyPendingUpsertsPrefix, historyPendingDeletesPrefix]
        let keys = store.dictionaryRepresentation().keys.sorted(by: >)
        var discoveredUserIds: [String] = []
        var seenUserIds = Set<String>()

        for key in keys {
            guard let prefix = knownPrefixes.first(where: { key.hasPrefix($0) }) else { continue }
            let userId = normalizeHistoryUserId(String(key.dropFirst(prefix.count)))
            guard !userId.isEmpty, seenUserIds.insert(userId).inserted else { continue }
            discoveredUserIds.append(userId)
        }

        return discoveredUserIds
    }

    private nonisolated static func shortcutPlaylistStorageKey(for slot: Int) -> String {
        "\(shortcutPlaylistPrefix)\(slot)"
    }

    private nonisolated static func configurationSnapshot(updatedAt: Date) -> ConfigurationSnapshot {
        var shortcutPlaylistIds: [Int: String] = [:]
        for slot in shortcutSlots {
            let playlistId = configuredShortcutPlaylistId(for: slot)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !playlistId.isEmpty {
                shortcutPlaylistIds[slot] = playlistId
            }
        }

        return ConfigurationSnapshot(
            selectedPlaylist: selectedPlaylistSnapshot(),
            defaultPlaylistId: defaultPlaylistId().trimmingCharacters(in: .whitespacesAndNewlines),
            shortcutPlaylistIds: shortcutPlaylistIds,
            playlistNamesById: loadPlaylistNamesById(),
            updatedAt: updatedAt
        )
    }

    private nonisolated static func loadPlaylistNamesById() -> [String: String] {
        let raw = store.string(forKey: playlistNamesByIdKey) ?? ""
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private nonisolated static func savePlaylistNamesById(_ playlistNamesById: [String: String]) {
        let normalized = playlistNamesById.reduce(into: [String: String]()) { result, entry in
            let trimmedId = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedName = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty, !trimmedName.isEmpty else { return }
            result[trimmedId] = trimmedName
        }

        guard !normalized.isEmpty else {
            removeStoreValue(forKey: playlistNamesByIdKey)
            return
        }

        guard let data = try? JSONEncoder().encode(normalized),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        setStoreValue(json, forKey: playlistNamesByIdKey)
    }

    private nonisolated static func saveSelectedPlaylistSnapshot(_ snapshot: SharedSelectedPlaylistSnapshot?) {
        guard let snapshot, !snapshot.isEmpty else {
            removeStoreValue(forKey: selectedPlaylistSnapshotKey)
            return
        }

        setStoreValue(
            [
                "id": snapshot.id,
                "name": snapshot.name,
                "description": snapshot.description,
                "artworkURL": snapshot.artworkURL
            ],
            forKey: selectedPlaylistSnapshotKey
        )
    }

    private nonisolated static func makeHistoryEncoder() -> JSONEncoder {
        JSONEncoder()
    }

    private nonisolated static func makeHistoryDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private nonisolated static func postHistoryDidChange(for userId: String) {
        postNotification(
            name: historyDidChangeNotification,
            userInfo: [historyDidChangeUserIdKey: userId]
        )
    }

    private nonisolated static func setOrRemove(_ value: String, forKey key: String) {
        if value.isEmpty {
            removeStoreValue(forKey: key)
        } else {
            setStoreValue(value, forKey: key)
        }
    }

    private nonisolated static func setStoreValue(_ value: Any?, forKey key: String) {
        performMainThreadMutation {
            store.set(value, forKey: key)
        }
    }

    private nonisolated static func removeStoreValue(forKey key: String) {
        performMainThreadMutation {
            store.removeObject(forKey: key)
        }
    }

    private nonisolated static func postNotification(
        name: Notification.Name,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        performMainThreadMutation {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        }
    }

    private nonisolated static func performMainThreadMutation(_ mutation: @escaping () -> Void) {
        if Thread.isMainThread {
            mutation()
            return
        }
        DispatchQueue.main.sync(execute: mutation)
    }
}

final class CloudAccountSyncService {
    static let shared = CloudAccountSyncService()

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let notificationCenter = NotificationCenter.default
    private let cloudSnapshotKey = "CloudAccountSnapshot"
    private let cloudConfigurationSnapshotKey = "CloudConfigurationSnapshot"
    private let cloudIOSBootstrapSnapshotKey = "CloudIOSBootstrapSnapshot"
    private let stateLock = NSLock()

    private var hasStarted = false
    private var changeObserver: NSObjectProtocol?

    private init() {}

    func start() {
        stateLock.lock()
        if hasStarted {
            stateLock.unlock()
            return
        }
        hasStarted = true
        stateLock.unlock()

#if os(iOS)
        SharedDefaults.migrateLegacyAccountIfNeeded()
#endif

        changeObserver = notificationCenter.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: .main
        ) { [weak self] _ in
            self?.mergeCloudStateIntoLocal()
        }

        _ = ubiquitousStore.synchronize()
        mergeCloudStateIntoLocal()

#if os(iOS)
        markIOSAppAvailable()
#endif
    }

    func refreshFromCloud() {
        _ = ubiquitousStore.synchronize()
        mergeCloudStateIntoLocal()
    }

    func updateLoggedInAccount(userId: String, displayName: String, avatarURL: String) {
        let snapshot = SharedDefaults.AccountSnapshot(
            spotifyLoggedIn: true,
            userId: userId,
            displayName: displayName,
            avatarURL: avatarURL,
            updatedAt: Date()
        )
        SharedDefaults.saveAccountSnapshot(snapshot)
        saveCloudSnapshot(snapshot)
    }

    func logout() {
        KeychainStore().deleteAllTokens()
        let snapshot = SharedDefaults.AccountSnapshot.loggedOut(updatedAt: Date())
        SharedDefaults.saveAccountSnapshot(snapshot)
        saveCloudSnapshot(snapshot)
    }

    func syncConfigurationFromLocal(updatedAt: Date = Date()) {
        let snapshot = SharedDefaults.currentConfigurationSnapshot(updatedAt: updatedAt)
        SharedDefaults.saveConfigurationSnapshot(snapshot)
        saveCloudConfigurationSnapshot(snapshot)
    }

#if os(macOS)
    func requestIOSLaunchFromMac() {
        let existingSnapshot = SharedDefaults.loadIOSBootstrapSnapshot()
        guard !existingSnapshot.iosAppLaunched else { return }
        guard !existingSnapshot.iosLaunchRequestedByMac else { return }

        let snapshot = SharedDefaults.IOSBootstrapSnapshot(
            iosAppLaunched: false,
            iosLaunchRequestedByMac: true,
            updatedAt: Date()
        )
        SharedDefaults.saveIOSBootstrapSnapshot(snapshot)
        saveCloudIOSBootstrapSnapshot(snapshot)
    }
#endif

    private func mergeCloudStateIntoLocal() {
        mergeCloudAccountSnapshotIntoLocal()
        mergeCloudConfigurationSnapshotIntoLocal()
        mergeCloudIOSBootstrapSnapshotIntoLocal()
    }

    private func mergeCloudAccountSnapshotIntoLocal() {
        let localSnapshot = SharedDefaults.loadAccountSnapshot()
        guard let cloudSnapshot = loadCloudSnapshot() else {
#if os(iOS)
            if !localSnapshot.isEmpty {
                saveCloudSnapshot(localSnapshot)
            }
#endif
            return
        }

#if os(macOS)
        applyCloudSnapshot(cloudSnapshot, previousLocalSnapshot: localSnapshot)
#else
        if cloudSnapshot.updatedAt > localSnapshot.updatedAt {
            applyCloudSnapshot(cloudSnapshot, previousLocalSnapshot: localSnapshot)
            return
        }

        if localSnapshot.updatedAt > cloudSnapshot.updatedAt {
            saveCloudSnapshot(localSnapshot)
        }
#endif
    }

    private func mergeCloudConfigurationSnapshotIntoLocal() {
        let localSnapshot = SharedDefaults.loadConfigurationSnapshot()
        guard let cloudSnapshot = loadCloudConfigurationSnapshot() else {
#if os(iOS)
            if !localSnapshot.isEmpty {
                saveCloudConfigurationSnapshot(localSnapshot)
            }
#endif
            return
        }

#if os(macOS)
        SharedDefaults.saveConfigurationSnapshot(cloudSnapshot)
#else
        if cloudSnapshot.updatedAt > localSnapshot.updatedAt {
            SharedDefaults.saveConfigurationSnapshot(cloudSnapshot)
            return
        }

        if localSnapshot.updatedAt > cloudSnapshot.updatedAt {
            saveCloudConfigurationSnapshot(localSnapshot)
        }
#endif
    }

    private func mergeCloudIOSBootstrapSnapshotIntoLocal() {
        let localSnapshot = SharedDefaults.loadIOSBootstrapSnapshot()
        guard let cloudSnapshot = loadCloudIOSBootstrapSnapshot() else {
#if os(iOS)
            if !localSnapshot.isEmpty {
                saveCloudIOSBootstrapSnapshot(localSnapshot)
            }
#endif
            return
        }

#if os(macOS)
        SharedDefaults.saveIOSBootstrapSnapshot(cloudSnapshot)
#else
        if cloudSnapshot.updatedAt > localSnapshot.updatedAt {
            SharedDefaults.saveIOSBootstrapSnapshot(cloudSnapshot)
            return
        }

        if localSnapshot.updatedAt > cloudSnapshot.updatedAt {
            saveCloudIOSBootstrapSnapshot(localSnapshot)
        }
#endif
    }

    private func applyCloudSnapshot(
        _ snapshot: SharedDefaults.AccountSnapshot,
        previousLocalSnapshot: SharedDefaults.AccountSnapshot
    ) {
        if previousLocalSnapshot.spotifyLoggedIn && !snapshot.spotifyLoggedIn {
            KeychainStore().deleteAllTokens()
        }
        SharedDefaults.saveAccountSnapshot(snapshot)
    }

    private func loadCloudSnapshot() -> SharedDefaults.AccountSnapshot? {
        guard let data = ubiquitousStore.data(forKey: cloudSnapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedDefaults.AccountSnapshot.self, from: data)
    }

    private func loadCloudConfigurationSnapshot() -> SharedDefaults.ConfigurationSnapshot? {
        guard let data = ubiquitousStore.data(forKey: cloudConfigurationSnapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedDefaults.ConfigurationSnapshot.self, from: data)
    }

    private func loadCloudIOSBootstrapSnapshot() -> SharedDefaults.IOSBootstrapSnapshot? {
        guard let data = ubiquitousStore.data(forKey: cloudIOSBootstrapSnapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedDefaults.IOSBootstrapSnapshot.self, from: data)
    }

    private func saveCloudSnapshot(_ snapshot: SharedDefaults.AccountSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        ubiquitousStore.set(data, forKey: cloudSnapshotKey)
        ubiquitousStore.synchronize()
    }

    private func saveCloudConfigurationSnapshot(_ snapshot: SharedDefaults.ConfigurationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        ubiquitousStore.set(data, forKey: cloudConfigurationSnapshotKey)
        ubiquitousStore.synchronize()
    }

    private func saveCloudIOSBootstrapSnapshot(_ snapshot: SharedDefaults.IOSBootstrapSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        ubiquitousStore.set(data, forKey: cloudIOSBootstrapSnapshotKey)
        ubiquitousStore.synchronize()
    }

#if os(iOS)
    private func markIOSAppAvailable() {
        let snapshot = SharedDefaults.IOSBootstrapSnapshot(
            iosAppLaunched: true,
            iosLaunchRequestedByMac: false,
            updatedAt: Date()
        )
        SharedDefaults.saveIOSBootstrapSnapshot(snapshot)
        saveCloudIOSBootstrapSnapshot(snapshot)
        syncConfigurationFromLocal()
    }
#endif
}
