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
        let targetPlaylistName = SharedDefaults.playlistName(for: playlistId)
        if !(await hasAuthContext()) {
            return failure("SchemaTraining: Übersprungen")
        }

        do {
            try await SpotifyAPI.shared.refreshSessionIfNeeded(forceRefresh: true)
            let resolvedPlaylistName = await resolvePlaylistName(
                playlistId: playlistId,
                playlistName: targetPlaylistName
            )
            let response = try await SpotifyAPI.shared.addCurrentTrack(playlistId: playlistId)
            let historyUserId = await resolveHistoryUserId()
            if !historyUserId.isEmpty {
                SharedDefaults.stageHistoryEntry(
                    .init(
                        trackName: response.trackName,
                        artistName: response.artistName,
                        artworkURL: response.artworkURL,
                        trackURI: response.trackURI,
                        status: "success",
                        playlistName: resolvedPlaylistName
                    ),
                    for: historyUserId
                )
                Task {
                    _ = await CloudHistorySyncService.shared.syncHistory(for: historyUserId)
                }
            }
            await NotificationHelper.notify(
                title: "\(response.trackName) von \(response.artistName)",
                body: successMessage(for: resolvedPlaylistName),
                artworkURLString: response.artworkURL
            )
            return success(trackName: response.trackName, trackId: response.trackId)
        } catch {
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                CloudAccountSyncService.shared.logout()
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
                let playlistName = SharedDefaults.playlistName(for: playlistId) ?? targetPlaylistName
                await NotificationHelper.notify(
                    title: "\(trackName) von \(artistName)",
                    body: duplicateMessage(for: playlistName),
                    artworkURLString: artworkURL
                )
                return failure(duplicateMessage(for: playlistName))
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
            if keychain.readAccessToken(authenticationUI: .fail) != nil { return true }
            if keychain.readRefreshToken(authenticationUI: .fail) != nil { return true }
            return false
        }
    }

    private static func resolveHistoryUserId() async -> String {
        let fromDefaults = SharedDefaults.accountUserId()
        if !fromDefaults.isEmpty {
            return fromDefaults
        }
        return (try? await SpotifyAPI.shared.fetchMe().id) ?? ""
    }

    private static func resolvePlaylistName(
        playlistId: String,
        playlistName: String?
    ) async -> String? {
        if let normalizedPlaylistName = normalizedPlaylistName(playlistName) {
            SharedDefaults.cachePlaylistName(normalizedPlaylistName, for: playlistId)
            return normalizedPlaylistName
        }

        if let cachedPlaylistName = SharedDefaults.playlistName(for: playlistId) {
            return cachedPlaylistName
        }

        guard let fetchedPlaylistName = try? await SpotifyAPI.shared.fetchPlaylistName(playlistId: playlistId) else {
            return nil
        }

        let normalizedFetchedName = normalizedPlaylistName(fetchedPlaylistName)
        if let normalizedFetchedName {
            SharedDefaults.cachePlaylistName(normalizedFetchedName, for: playlistId)
        }
        return normalizedFetchedName
    }

    private static func successMessage(for playlistName: String?) -> String {
        if let formattedPlaylistName = formattedPlaylistName(playlistName) {
            return "Gespeichert in \(formattedPlaylistName)"
        }
        return "Erfolgreich hinzugefügt"
    }

    private static func duplicateMessage(for playlistName: String?) -> String {
        if let formattedPlaylistName = formattedPlaylistName(playlistName) {
            return "Bereits in \(formattedPlaylistName)"
        }
        return "Bereits vorhanden"
    }

    private static func normalizedPlaylistName(_ playlistName: String?) -> String? {
        let trimmedName = (playlistName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        return trimmedName
    }

    private static func formattedPlaylistName(_ playlistName: String?) -> String? {
        guard let normalizedPlaylistName = normalizedPlaylistName(playlistName) else { return nil }
        return "„\(normalizedPlaylistName)“"
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

    static func intentDialog(for output: String) -> IntentDialog {
        if output.hasPrefix("~~~") {
            let message = String(output.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                return IntentDialog(full: "\(message)", systemImageName: "exclamationmark.triangle.fill")
            }
            return IntentDialog(full: "Speichern fehlgeschlagen", systemImageName: "exclamationmark.triangle.fill")
        }

        let trackName = output
            .components(separatedBy: "~success~")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !trackName.isEmpty {
            return IntentDialog(full: "\(trackName) gespeichert", systemImageName: "checkmark.circle.fill")
        }
        return IntentDialog(full: "Track gespeichert", systemImageName: "checkmark.circle.fill")
    }
}

struct SaveCurrentTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Aktuellen Song speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuell spielenden Song über TrackSaver in die Playlist des aktiven Schicht-Segments.")
    }

    func perform() async throws -> some IntentResult {
        let output = await SaveTrackIntentRunner.perform(shortcutSlot: nil)
        return .result(value: output, dialog: SaveTrackIntentRunner.intentDialog(for: output))
    }
}

struct SaveCurrentTrackShift1Intent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Schicht 1 speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuellen Song in die für Schicht 1 konfigurierte Playlist.")
    }

    func perform() async throws -> some IntentResult {
        let output = await SaveTrackIntentRunner.perform(shortcutSlot: 1)
        return .result(value: output, dialog: SaveTrackIntentRunner.intentDialog(for: output))
    }
}

struct SaveCurrentTrackShift2Intent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Schicht 2 speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuellen Song in die für Schicht 2 konfigurierte Playlist.")
    }

    func perform() async throws -> some IntentResult {
        let output = await SaveTrackIntentRunner.perform(shortcutSlot: 2)
        return .result(value: output, dialog: SaveTrackIntentRunner.intentDialog(for: output))
    }
}

struct SaveCurrentTrackShift3Intent: AppIntent {
    static var title: LocalizedStringResource = "TrackSaver: Schicht 3 speichern"
    static var openAppWhenRun: Bool = false

    static var description: IntentDescription? {
        IntentDescription("Speichert den aktuellen Song in die für Schicht 3 konfigurierte Playlist.")
    }

    func perform() async throws -> some IntentResult {
        let output = await SaveTrackIntentRunner.perform(shortcutSlot: 3)
        return .result(value: output, dialog: SaveTrackIntentRunner.intentDialog(for: output))
    }
}
