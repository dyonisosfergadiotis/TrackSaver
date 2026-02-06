import Foundation

enum SharedDefaults {
    static let suiteName = "group.dyonisosfergadiotis.tracksaver"
    static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    static func migrateDefaultPlaylistIdIfNeeded() {
        let sharedValue = store.string(forKey: "DefaultPlaylistId") ?? ""
        if !sharedValue.isEmpty { return }
        let legacyValue = UserDefaults.standard.string(forKey: "DefaultPlaylistId") ?? ""
        guard !legacyValue.isEmpty else { return }
        store.set(legacyValue, forKey: "DefaultPlaylistId")
    }
}
