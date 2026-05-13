import Foundation

enum TrackSaveService {
    struct SaveResult {
        let response: SpotifyAPI.AddTrackResult
        let historyEntry: SharedDefaults.HistoryEntry?
        let historyUserId: String
        let playlistName: String?
    }

    static func saveCurrentTrack(
        playlistId: String,
        playlistName: String?
    ) async throws -> SaveResult {
        try await SpotifyAPI.shared.refreshSessionIfNeeded(forceRefresh: true)
        let resolvedPlaylistName = await resolvePlaylistName(
            playlistId: playlistId,
            playlistName: playlistName
        )
        let response = try await SpotifyAPI.shared.addCurrentTrack(playlistId: playlistId)
        let historyUserId = await resolveHistoryUserId()

        let historyEntry: SharedDefaults.HistoryEntry?
        if !historyUserId.isEmpty {
            let entry = SharedDefaults.HistoryEntry(
                trackName: response.trackName,
                artistName: response.artistName,
                artworkURL: response.artworkURL,
                trackURI: response.trackURI,
                status: "success",
                playlistName: resolvedPlaylistName
            )
            SharedDefaults.stageHistoryEntry(entry, for: historyUserId)
            enqueueHistorySync(for: historyUserId)
            historyEntry = entry
        } else {
            historyEntry = nil
        }

        return SaveResult(
            response: response,
            historyEntry: historyEntry,
            historyUserId: historyUserId,
            playlistName: resolvedPlaylistName
        )
    }

    static func successMessage(for playlistName: String?) -> String {
        if let formattedPlaylistName = formattedPlaylistName(playlistName) {
            return "Gespeichert in \(formattedPlaylistName)"
        }
        return "Erfolgreich hinzugefügt"
    }

    static func duplicateMessage(for playlistName: String?) -> String {
        if let formattedPlaylistName = formattedPlaylistName(playlistName) {
            return "Bereits in \(formattedPlaylistName)"
        }
        return "Bereits vorhanden"
    }

    static func duplicateBannerMessage(for playlistName: String?) -> String {
        if let formattedPlaylistName = formattedPlaylistName(playlistName) {
            return "Song ist bereits in \(formattedPlaylistName)."
        }
        return "Song ist bereits in der Playlist."
    }

    private static func enqueueHistorySync(for userId: String) {
        guard !userId.isEmpty else { return }
        Task {
            _ = await CloudHistorySyncService.shared.syncHistory(for: userId)
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

    private static func normalizedPlaylistName(_ playlistName: String?) -> String? {
        let trimmedName = (playlistName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        return trimmedName
    }

    private static func formattedPlaylistName(_ playlistName: String?) -> String? {
        guard let normalizedPlaylistName = normalizedPlaylistName(playlistName) else { return nil }
        return "„\(normalizedPlaylistName)“"
    }
}
