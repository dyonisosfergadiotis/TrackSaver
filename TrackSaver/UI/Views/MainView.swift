import SwiftUI

struct MainView: View {
    // MARK: - Data Model
    // Local history model persisted in AppStorage.
    struct HistoryItem: Identifiable, Codable {
        let id = UUID()
        let trackName: String
        let artistName: String
        let artworkURL: String?
        let date: Date
        let status: String // "success" | "fail"
        let playlistName: String?
    }

    // MARK: - Storage & UI State
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("LocalHistoryJSON") private var historyJSON: String = ""
    @AppStorage("DefaultPlaylistId", store: SharedDefaults.store) private var defaultPlaylistId: String = ""

    @State private var history: [HistoryItem] = []
    @State private var playlists: [SpotifyAPI.Playlist] = []
    @State private var selectedPlaylistId: String?

    private var selectedPlaylist: SpotifyAPI.Playlist? {
        playlists.first { $0.id == selectedPlaylistId }
    }

    // Controls the Maps-style bottom sheet behavior for playlists.
    @State private var showPlaylistSheet = true
    @State private var playlistSheetDetent: PresentationDetent = .height(80)
    @State private var showSettingsSheet = false
    @State private var isSaving = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                // Main content scrolls behind the persistent playlist sheet.
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        historySection
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            // Persistent playlist sheet (Maps-like) with multiple detents.
            .sheet(isPresented: $showPlaylistSheet) {
                PlaylistSheetView(
                    playlists: playlists,
                    selectedId: $selectedPlaylistId,
                    selectedPlaylist: selectedPlaylist,
                    isSaving: isSaving, 
                    detent: $playlistSheetDetent,
                    onSelect: { playlist in
                        await setDefaultPlaylist(playlist)
                    },
                    onSave: {
                        saveCurrentTrack()
                    },
                    onRefresh: {
                        await refreshPlaylists()
                    }
                )
                .presentationDetents([.height(80), .medium], selection: $playlistSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(80)))
                //.presentationCornerRadius(28)
                .interactiveDismissDisabled()
            }
            // Settings is a standard, non-resizable sheet.
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
            .task {
                // Initial load for playlists and local history.
                if !hasLoaded {
                    SharedDefaults.migrateDefaultPlaylistIdIfNeeded()
                    KeychainStore().migrateLegacyTokensIfNeeded()
                    await loadData()
                    loadHistoryFromStorage()
                }
                // Ensure the sheet starts minimized so the pill is visible immediately.
                playlistSheetDetent = .height(80)
                showPlaylistSheet = true
            }
        }
    }

    // MARK: - Data Loading
    private func loadData() async {
        hasLoaded = true
        do {
            // Fetch account + playlists and filter to editable lists.
            async let meCall = SpotifyAPI.shared.fetchMe()
            async let playlistsCall = SpotifyAPI.shared.fetchPlaylists()
            let (me, playlistsResp) = try await (meCall, playlistsCall)
            playlists = filterEditablePlaylists(playlistsResp, userId: me.id)
            if !defaultPlaylistId.isEmpty, playlistsResp.contains(where: { $0.id == defaultPlaylistId }) {
                selectedPlaylistId = defaultPlaylistId
            } else if let fallback = playlistsResp.first?.id {
                selectedPlaylistId = fallback
            } else {
                selectedPlaylistId = nil
            }
        } catch {
            handleAPIError(error)
        }
    }

    private func refreshPlaylists() async {
        do {
            // Same logic as initial load, triggered by refresh button.
            async let meCall = SpotifyAPI.shared.fetchMe()
            async let playlistsCall = SpotifyAPI.shared.fetchPlaylists()
            let (me, playlistsResp) = try await (meCall, playlistsCall)
            playlists = filterEditablePlaylists(playlistsResp, userId: me.id)
            if !defaultPlaylistId.isEmpty, playlistsResp.contains(where: { $0.id == defaultPlaylistId }) {
                selectedPlaylistId = defaultPlaylistId
            } else if let fallback = playlistsResp.first?.id {
                selectedPlaylistId = fallback
            } else {
                selectedPlaylistId = nil
            }
        } catch {
            handleAPIError(error)
        }
    }

    // Filters playlists to only those the user can modify (owned or collaborative).
    private func filterEditablePlaylists(_ input: [SpotifyAPI.Playlist], userId: String) -> [SpotifyAPI.Playlist] {
        input.filter { playlist in
            if playlist.owner.id == userId { return true }
            if playlist.collaborative == true { return true }
            return false
        }
    }

    // Updates the in-app default playlist selection.
    private func setDefaultPlaylist(_ playlist: SpotifyAPI.Playlist) async {
        selectedPlaylistId = playlist.id
        defaultPlaylistId = playlist.id
    }

    // Handles auth errors by clearing tokens and returning to login.
    private func handleAPIError(_ error: Error) {
        if let apiError = error as? SpotifyAPIError {
            switch apiError {
            case .unauthorized:
                KeychainStore().deleteAllTokens()
                spotifyLoggedIn = false
            default:
                break
            }
        }
    }

    // MARK: - Local History
    private func loadHistoryFromStorage() {
        guard !historyJSON.isEmpty, let data = historyJSON.data(using: .utf8) else { return }
        if let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.history = decoded
        }
    }

    private func saveHistoryToStorage() {
        if let data = try? JSONEncoder().encode(history), let json = String(data: data, encoding: .utf8) {
            historyJSON = json
        }
    }

    private func deleteHistory(at index: Int) {
        guard history.indices.contains(index) else { return }
        history.remove(at: index)
        saveHistoryToStorage()
    }

    // MARK: - Save Current Track
    private func saveCurrentTrack() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            do {
                guard let playlistId = selectedPlaylistId else {
                    isSaving = false
                    return
                }
                // The Spotify API call handles duplicate/no-playback checks.
                let resp = try await SpotifyAPI.shared.addCurrentTrack(playlistId: playlistId)
                let entry = HistoryItem(
                    trackName: resp.trackName,
                    artistName: resp.artistName,
                    artworkURL: resp.artworkURL,
                    date: Date(),
                    status: "success",
                    playlistName: selectedPlaylist?.name
                )
                history.insert(entry, at: 0)
                saveHistoryToStorage()
                await NotificationHelper.notify(
                    title: resp.artistName,
                    body: "Erfolgreich hinzugefügt",
                    artworkURLString: resp.artworkURL
                )
                isSaving = false
            } catch {
                if let apiError = error as? SpotifyAPIError {
                    switch apiError {
                    case .noCurrentTrack:
                        await NotificationHelper.notify(
                            title: "Kein Track",
                            body: "Es läuft gerade kein Song"
                        )
                        isSaving = false
                        return
                    case .duplicateTrack(_, let artistName, let artworkURL):
                        await NotificationHelper.notify(
                            title: artistName,
                            body: "Bereits vorhanden",
                            artworkURLString: artworkURL
                        )
                        isSaving = false
                        return
                    default:
                        break
                    }
                }
                handleAPIError(error)
                let entry = HistoryItem(
                    trackName: "—",
                    artistName: "—",
                    artworkURL: nil,
                    date: Date(),
                    status: "fail",
                    playlistName: selectedPlaylist?.name
                )
                history.insert(entry, at: 0)
                saveHistoryToStorage()
                isSaving = false
            }
        }
    }
}

private extension MainView {
    // MARK: - Header UI
    var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TrackSaver")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                showSettingsSheet = true
            } label: {
                IconBadge(systemName: "gearshape.fill")
            }
        }
    }

    // MARK: - History UI
    var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Historie")
            if history.isEmpty {
                GlassCard {
                    Text("Noch nichts gespeichert. Starte mit dem Button oben.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                        HistoryRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteHistory(at: index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

}

// MARK: - History Row UI
private struct HistoryRow: View {
    let item: MainView.HistoryItem

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                artwork
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.trackName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(item.artistName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        if let name = item.playlistName, !name.isEmpty {
                            Text(name)
                        } else {
                            Text("Playlist")
                        }
                        Text("·")
                        Text(formattedDate(item.date))
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: item.status == "success" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(item.status == "success" ? StyleKit.accent : .orange)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let urlString = item.artworkURL, let url = URL(string: urlString) {
            RemoteImage(url: url) { artworkFallback }
                .scaledToFill()
        } else {
            artworkFallback
        }
    }

    private var artworkFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.12))
            Image(systemName: "music.note")
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Gestern"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct PlaylistPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.secondary)
                    )
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Image(systemName: "chevron.up")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainView()
}
