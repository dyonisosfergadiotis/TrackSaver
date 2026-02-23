import Foundation

enum SharedDefaults {
    static let suiteName = "group.dyonisosfergadiotis.tracksaver"
    static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    private static let defaultPlaylistKey = "DefaultPlaylistId"
    private static let shortcutPlaylistPrefix = "ShortcutPlaylistId."
    private static let historyPrefix = "LocalHistoryJSON."
    private static let legacyHistoryKey = "LocalHistoryJSON"
    static let shortcutSlots = [1, 2, 3]

    static func migrateDefaultPlaylistIdIfNeeded() {
        let sharedValue = store.string(forKey: defaultPlaylistKey) ?? ""
        if !sharedValue.isEmpty { return }
        let legacyValue = UserDefaults.standard.string(forKey: defaultPlaylistKey) ?? ""
        guard !legacyValue.isEmpty else { return }
        store.set(legacyValue, forKey: defaultPlaylistKey)
    }

    static func defaultPlaylistId() -> String {
        store.string(forKey: defaultPlaylistKey) ?? ""
    }

    static func setDefaultPlaylistId(_ playlistId: String) {
        store.set(playlistId, forKey: defaultPlaylistKey)
    }

    static func configuredShortcutPlaylistId(for slot: Int) -> String {
        guard shortcutSlots.contains(slot) else { return "" }
        return store.string(forKey: shortcutPlaylistStorageKey(for: slot)) ?? ""
    }

    static func shortcutPlaylistId(for slot: Int) -> String {
        let configured = configuredShortcutPlaylistId(for: slot)
        if !configured.isEmpty {
            return configured
        }
        return defaultPlaylistId()
    }

    static func setShortcutPlaylistId(_ playlistId: String, for slot: Int) {
        guard shortcutSlots.contains(slot) else { return }
        let trimmed = playlistId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            store.removeObject(forKey: shortcutPlaylistStorageKey(for: slot))
            return
        }
        store.set(trimmed, forKey: shortcutPlaylistStorageKey(for: slot))
    }

    static func clearShortcutPlaylistId(for slot: Int) {
        guard shortcutSlots.contains(slot) else { return }
        store.removeObject(forKey: shortcutPlaylistStorageKey(for: slot))
    }

    static func resolvedShortcutPlaylistId(for slot: Int?) -> String {
        if let slot {
            return shortcutPlaylistId(for: slot)
        }
        return shortcutPlaylistId(for: shortcutSlotForCurrentSegment())
    }

    static func hasAnyConfiguredShortcutPlaylist() -> Bool {
        if !defaultPlaylistId().isEmpty {
            return true
        }
        for slot in shortcutSlots where !configuredShortcutPlaylistId(for: slot).isEmpty {
            return true
        }
        return false
    }

    // 3x8h split for Schicht-Shortcuts: 06-14, 14-22, 22-06
    static func shortcutSlotForCurrentSegment(date: Date = Date(), calendar: Calendar = .current) -> Int {
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

    static func historyKey(for userId: String) -> String {
        "\(historyPrefix)\(userId)"
    }

    static func loadHistoryJSON(for userId: String) -> String {
        store.string(forKey: historyKey(for: userId)) ?? ""
    }

    static func saveHistoryJSON(_ json: String, for userId: String) {
        store.set(json, forKey: historyKey(for: userId))
    }

    static func clearHistory(for userId: String) {
        store.removeObject(forKey: historyKey(for: userId))
    }

    static func migrateLegacyHistoryIfNeeded(for userId: String) {
        let targetKey = historyKey(for: userId)
        let existing = store.string(forKey: targetKey) ?? ""
        if !existing.isEmpty { return }

        let sharedLegacy = store.string(forKey: legacyHistoryKey) ?? ""
        if !sharedLegacy.isEmpty {
            store.set(sharedLegacy, forKey: targetKey)
            store.removeObject(forKey: legacyHistoryKey)
            return
        }

        let standardLegacy = UserDefaults.standard.string(forKey: legacyHistoryKey) ?? ""
        guard !standardLegacy.isEmpty else { return }
        store.set(standardLegacy, forKey: targetKey)
        UserDefaults.standard.removeObject(forKey: legacyHistoryKey)
    }

    private static func shortcutPlaylistStorageKey(for slot: Int) -> String {
        "\(shortcutPlaylistPrefix)\(slot)"
    }
}
