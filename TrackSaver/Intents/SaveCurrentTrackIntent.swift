import AppIntents

struct SaveCurrentTrackIntent: AppIntent {
    // SSU/Schema training should not execute live network logic.
    private var isSchemaTraining: Bool {
        if let exec = ProcessInfo.processInfo.arguments.first, exec.localizedCaseInsensitiveContains("AppIntents") { return true }
        if let bundleName = Bundle.main.bundleURL.lastPathComponent as String?, bundleName.localizedCaseInsensitiveContains("Intents") { return true }
        if ProcessInfo.processInfo.environment["INTENTS_SCHEMA_TRAINING"] != nil { return true }
        return false
    }

    private func hasAuthContext() -> Bool {
        let playlistId = SharedDefaults.store.string(forKey: "DefaultPlaylistId") ?? ""
        guard !playlistId.isEmpty else { return false }
        let keychain = KeychainStore()
        if keychain.readAccessToken() != nil { return true }
        if keychain.readRefreshToken() != nil { return true }
        return false
    }

    static var title: LocalizedStringResource = "TrackSaver: Aktuellen Song speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuell spielenden Song über TrackSaver, ohne die App zu öffnen.")
    }

    func perform() async throws -> some IntentResult {
        // During Shortcuts schema training or when required context is missing, avoid live work.
        if isSchemaTraining || !hasAuthContext() {
            return .result(value: "~~~SchemaTraining: Übersprungen")
        }

        let playlistId = SharedDefaults.store.string(forKey: "DefaultPlaylistId") ?? ""
        guard !playlistId.isEmpty else {
            return .result(value: "~~~Keine Playlist gesetzt")
        }
        do {
            let resp = try await SpotifyAPI.shared.addCurrentTrack(playlistId: playlistId)
            await NotificationHelper.notify(
                title: resp.artistName,
                body: "Erfolgreich hinzugefügt",
                artworkURLString: resp.artworkURL
            )
            return .result(value: "\(resp.trackName)~success~\(resp.trackId)")
        } catch {
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                KeychainStore().deleteAllTokens()
                return .result(value: "~~~Nicht autorisiert")
            }
            if let apiError = error as? SpotifyAPIError, case .noCurrentTrack = apiError {
                await NotificationHelper.notify(
                    title: "Kein Track",
                    body: "Es läuft gerade kein Song"
                )
                return .result(value: "~~~Kein laufender Track")
            }
            if case let .duplicateTrack(_, artistName, artworkURL) = (error as? SpotifyAPIError) {
                await NotificationHelper.notify(
                    title: artistName,
                    body: "Bereits vorhanden",
                    artworkURLString: artworkURL
                )
                return .result(value: "~~~Bereits in Playlist")
            }
            return .result(value: "~~~\(error.localizedDescription)")
        }
    }
}
