import AppIntents

enum SaveTrackIntentRunner {
    static func perform(shortcutSlot: Int?) async -> String {
        // During Shortcuts schema training or when required context is missing, avoid live work.
        if isSchemaTraining {
            return failure("SchemaTraining: Übersprungen")
        }

        let playlistId = await MainActor.run {
            SharedDefaults.resolvedShortcutPlaylistId(for: shortcutSlot)
        }
        guard !playlistId.isEmpty else {
            return failure("Keine Playlist gesetzt")
        }
        if !(await hasAuthContext()) {
            return failure("SchemaTraining: Übersprungen")
        }

        do {
            let resp = try await SpotifyAPI.shared.addCurrentTrack(playlistId: playlistId)
            await NotificationHelper.notify(
                title: "\(resp.trackName) von \(resp.artistName)",
                body: "Erfolgreich hinzugefügt",
                artworkURLString: resp.artworkURL
            )
            return success(trackName: resp.trackName, trackId: resp.trackId)
        } catch {
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                await MainActor.run {
                    KeychainStore().deleteAllTokens()
                }
                return failure("Nicht autorisiert")
            }
            if let apiError = error as? SpotifyAPIError, case .noCurrentTrack = apiError {
                await NotificationHelper.notify(
                    title: "Kein Track",
                    body: "Es läuft gerade kein Song"
                )
                return failure("Kein laufender Track")
            }
            if case let .duplicateTrack(trackName, artistName, artworkURL) = (error as? SpotifyAPIError) {
                await NotificationHelper.notify(
                    title: "\(trackName) von \(artistName)",
                    body: "Bereits vorhanden",
                    artworkURLString: artworkURL
                )
                return failure("Bereits in Playlist")
            }
            return failure(error.localizedDescription)
        }
    }

    private static var isSchemaTraining: Bool {
        if let exec = ProcessInfo.processInfo.arguments.first, exec.localizedCaseInsensitiveContains("AppIntents") { return true }
        if let bundleName = Bundle.main.bundleURL.lastPathComponent as String?, bundleName.localizedCaseInsensitiveContains("Intents") { return true }
        if ProcessInfo.processInfo.environment["INTENTS_SCHEMA_TRAINING"] != nil { return true }
        return false
    }

    private static func hasAuthContext() async -> Bool {
        return await MainActor.run {
            let keychain = KeychainStore()
            if keychain.readAccessToken() != nil { return true }
            if keychain.readRefreshToken() != nil { return true }
            return false
        }
    }

    private static func success(trackName: String, trackId: String) -> String {
        "\(encodeSegment(trackName))~success~\(encodeSegment(trackId))"
    }

    private static func failure(_ message: String) -> String {
        "~~~\(encodeSegment(message))"
    }

    private static func encodeSegment(_ value: String) -> String {
        value
            .replacingOccurrences(of: "~", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

struct SaveCurrentTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Aktuellen Song speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuell spielenden Song über TrackSaver in die Playlist des aktiven Schicht-Segments.")
    }

    func perform() async throws -> some IntentResult {
        return .result(value: await SaveTrackIntentRunner.perform(shortcutSlot: nil))
    }
}

struct SaveCurrentTrackShift1Intent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Schicht 1 speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuellen Song in die für Schicht 1 konfigurierte Playlist.")
    }

    func perform() async throws -> some IntentResult {
        return .result(value: await SaveTrackIntentRunner.perform(shortcutSlot: 1))
    }
}

struct SaveCurrentTrackShift2Intent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Schicht 2 speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuellen Song in die für Schicht 2 konfigurierte Playlist.")
    }

    func perform() async throws -> some IntentResult {
        return .result(value: await SaveTrackIntentRunner.perform(shortcutSlot: 2))
    }
}

struct SaveCurrentTrackShift3Intent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Schicht 3 speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuellen Song in die für Schicht 3 konfigurierte Playlist.")
    }

    func perform() async throws -> some IntentResult {
        return .result(value: await SaveTrackIntentRunner.perform(shortcutSlot: 3))
    }
}
