import SwiftUI

struct MainView: View {
    // MARK: - Data Model
    // Local history model persisted per Spotify user in shared defaults.
    struct HistoryItem: Identifiable, Codable {
        let id: UUID
        let trackName: String
        let artistName: String
        let artworkURL: String?
        let date: Date
        let status: String // "success" | "fail"
        let playlistName: String?

        init(
            id: UUID = UUID(),
            trackName: String,
            artistName: String,
            artworkURL: String?,
            date: Date,
            status: String,
            playlistName: String?
        ) {
            self.id = id
            self.trackName = trackName
            self.artistName = artistName
            self.artworkURL = artworkURL
            self.date = date
            self.status = status
            self.playlistName = playlistName
        }
    }

    // MARK: - Storage & UI State
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("AccountUserId") private var accountUserId: String = ""
    @AppStorage("AccountDisplayName") private var accountDisplayName: String = ""
    @AppStorage("DefaultPlaylistId", store: SharedDefaults.store) private var defaultPlaylistId: String = ""

    @State private var history: [HistoryItem] = []
    @State private var playlists: [SpotifyAPI.Playlist] = []
    @State private var selectedPlaylistId: String?

    private var selectedPlaylist: SpotifyAPI.Playlist? {
        playlists.first { $0.id == selectedPlaylistId }
    }

    // Bottom accessory + playlist picker sheet.
    @State private var showPlaylistPicker = false
    @State private var playlistPickerDetent: PresentationDetent = .medium
    @State private var showSettingsSheet = false
    @State private var isSaving = false
    @State private var isRefreshingPlaylists = false
    @State private var isLoadingInitialData = false
    @State private var hasLoaded = false
    @State private var historyUserId: String = ""
    @State private var errorBannerMessage: String?
    @State private var errorBannerTask: Task<Void, Never>?

    private let maxHistoryItems = 250
    private let historyMutationAnimation: Animation = .snappy(duration: 0.36, extraBounce: 0.10)

    private var canSaveCurrentTrack: Bool {
        selectedPlaylistId != nil && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                // Main content scrolls behind the persistent bottom accessory.
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        historySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 126)
                }
                .overlay {
                    if isLoadingInitialData {
                        ProgressView("Lade Playlists…")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(StyleKit.surface)
                                    .overlay(Capsule().stroke(StyleKit.stroke, lineWidth: 1))
                                    .glassEffect(
                                        StyleKit.glass(tint: StyleKit.accent.opacity(0.12)),
                                        in: Capsule()
                                    )
                            )
                    }
                }
                .overlay(alignment: .top) {
                    if let errorBannerMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorBannerMessage)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.42))
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                .glassEffect(
                                    StyleKit.glass(tint: Color.red.opacity(0.30)),
                                    in: Capsule()
                                )
                        )
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                playlistAccessory
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            .sheet(isPresented: $showPlaylistPicker) {
                PlaylistSheetView(
                    playlists: playlists,
                    selectedId: $selectedPlaylistId,
                    selectedPlaylist: selectedPlaylist,
                    isRefreshing: isRefreshingPlaylists,
                    isLoadingPlaylists: isLoadingInitialData,
                    detent: $playlistPickerDetent,
                    allowsCollapse: false,
                    onSelect: { playlist in
                        await setDefaultPlaylist(playlist)
                    },
                    onRefresh: {
                        await refreshPlaylists()
                    }
                )
                .presentationDetents([.medium, .large], selection: $playlistPickerDetent)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
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
                    await reloadData(showInitialLoading: true, forceHistoryReload: true)
                }
            }
            .onChange(of: accountUserId) { _, newUserId in
                guard !newUserId.isEmpty, newUserId != historyUserId else { return }
                historyUserId = newUserId
                SharedDefaults.migrateLegacyHistoryIfNeeded(for: newUserId)
                loadHistoryFromStorage(for: newUserId)
            }
        }
    }

    // MARK: - Data Loading
    private func refreshPlaylists() async {
        await reloadData(showInitialLoading: false, forceHistoryReload: false)
    }

    private func reloadData(showInitialLoading: Bool, forceHistoryReload: Bool) async {
        hasLoaded = true
        if showInitialLoading {
            isLoadingInitialData = true
        } else {
            isRefreshingPlaylists = true
        }
        defer {
            isLoadingInitialData = false
            isRefreshingPlaylists = false
        }

        do {
            async let meCall = SpotifyAPI.shared.fetchMe()
            async let playlistsCall = SpotifyAPI.shared.fetchPlaylists()
            let (me, playlistsResp) = try await (meCall, playlistsCall)
            let editablePlaylists = filterEditablePlaylists(playlistsResp, userId: me.id)
            playlists = editablePlaylists

            if !defaultPlaylistId.isEmpty, editablePlaylists.contains(where: { $0.id == defaultPlaylistId }) {
                selectedPlaylistId = defaultPlaylistId
            } else if let existing = selectedPlaylistId, editablePlaylists.contains(where: { $0.id == existing }) {
                selectedPlaylistId = existing
            } else if let fallback = editablePlaylists.first?.id {
                selectedPlaylistId = fallback
            } else {
                selectedPlaylistId = nil
            }

            if forceHistoryReload || historyUserId != me.id {
                historyUserId = me.id
                SharedDefaults.migrateLegacyHistoryIfNeeded(for: me.id)
                loadHistoryFromStorage(for: me.id)
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
                showErrorBanner(apiError.errorDescription ?? error.localizedDescription)
            }
            return
        }
        showErrorBanner(error.localizedDescription)
    }

    // MARK: - Local History
    private func loadHistoryFromStorage(for userId: String) {
        let stored = SharedDefaults.loadHistoryJSON(for: userId)
        guard !stored.isEmpty, let data = stored.data(using: .utf8) else {
            history = []
            return
        }
        if let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.history = decoded
        } else {
            self.history = []
        }
    }

    private func saveHistoryToStorage() {
        let effectiveUserId = historyUserId.isEmpty ? accountUserId : historyUserId
        guard !effectiveUserId.isEmpty else { return }
        if let data = try? JSONEncoder().encode(history), let json = String(data: data, encoding: .utf8) {
            SharedDefaults.saveHistoryJSON(json, for: effectiveUserId)
        }
    }

    private func appendHistory(_ item: HistoryItem) {
        withAnimation(historyMutationAnimation) {
            history.insert(item, at: 0)
            if history.count > maxHistoryItems {
                history = Array(history.prefix(maxHistoryItems))
            }
        }
        saveHistoryToStorage()
    }

    private func deleteHistory(itemId: UUID) {
        guard let index = history.firstIndex(where: { $0.id == itemId }) else { return }
        withAnimation(historyMutationAnimation) {
            history.remove(at: index)
        }
        saveHistoryToStorage()
    }

    // MARK: - Save Current Track
    private func saveCurrentTrack() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            do {
                guard let playlistId = selectedPlaylistId else {
                    showErrorBanner("Bitte zuerst eine Playlist auswählen.")
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
                appendHistory(entry)
                await NotificationHelper.notify(
                    title: "\(resp.trackName) von \(resp.artistName)",
                    body: "Erfolgreich hinzugefügt",
                    artworkURLString: resp.artworkURL
                )
                isSaving = false
            } catch {
                if let apiError = error as? SpotifyAPIError {
                    switch apiError {
                    case .noCurrentTrack:
                        showErrorBanner("Es läuft gerade kein Song.")
                        await NotificationHelper.notify(
                            title: "Kein Track",
                            body: "Es läuft gerade kein Song"
                        )
                        isSaving = false
                        return
                    case .duplicateTrack(let trackName, let artistName, let artworkURL):
                        showErrorBanner("Song ist bereits in der Playlist.")
                        await NotificationHelper.notify(
                            title: "\(trackName) von \(artistName)",
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
                isSaving = false
            }
        }
    }

    private func showErrorBanner(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            errorBannerMessage = message
        }
        errorBannerTask?.cancel()
        errorBannerTask = Task {
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    errorBannerMessage = nil
                }
            }
        }
    }
}

private extension MainView {
    // MARK: - Bottom Accessory
    var playlistAccessory: some View {
        HStack(spacing: 10) {
            Button {
                playlistPickerDetent = .medium
                showPlaylistPicker = true
            } label: {
                HStack(spacing: 10) {
                    playlistAccessoryArtwork
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedPlaylist?.name ?? "Playlist wählen")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(StyleKit.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if let subtitle = selectedPlaylistSubtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(StyleKit.textMuted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("Standard-Playlist")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(StyleKit.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(StyleKit.surfaceSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(StyleKit.strokeSoft, lineWidth: 1)
                        )
                        .glassEffect(
                            StyleKit.glass(tint: StyleKit.accent.opacity(0.10), interactive: true),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StyleKit.Radius.accessory, style: .continuous)
                .fill(StyleKit.surfaceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: StyleKit.Radius.accessory, style: .continuous)
                        .stroke(StyleKit.stroke, lineWidth: 1)
                )
                .glassEffect(
                    StyleKit.glass(tint: StyleKit.accent.opacity(0.11), interactive: true),
                    in: RoundedRectangle(cornerRadius: StyleKit.Radius.accessory, style: .continuous)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 5)
        )
    }

    @ViewBuilder
    var playlistAccessoryArtwork: some View {
        if let urlString = selectedPlaylist?.images?.first?.url, let url = URL(string: urlString) {
            RemoteImage(url: url) { playlistAccessoryFallbackArtwork }
                .scaledToFill()
                .id(url.absoluteString)
        } else {
            playlistAccessoryFallbackArtwork
        }
    }

    var playlistAccessoryFallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(StyleKit.surfaceStrong)
            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StyleKit.textMuted)
        }
    }

    var selectedPlaylistSubtitle: String? {
        let trimmed = (selectedPlaylist?.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Header UI
    var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TrackSaver")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(StyleKit.textPrimary)
                Text(accountDisplayName.isEmpty ? "Speichere den laufenden Track ohne Reibung." : "Hi \(accountDisplayName), alles bereit für den nächsten Save.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
                    .lineLimit(2)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Historie")
                Spacer()
                if !history.isEmpty {
                    Text("\(history.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textMuted)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(StyleKit.surfaceSoft)
                                .overlay(Capsule().stroke(StyleKit.strokeSoft, lineWidth: 1))
                        )
                }
            }
            if history.isEmpty {
                GlassCard(style: .compact) {
                    Text("Noch nichts gespeichert. Nutze „Sichern“ in der Leiste unten.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(StyleKit.textSecondary)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, item in
                        let cardStyle: GlassCardStyle = index.isMultiple(of: 3) ? .standard : .compact
                        SwipeToDeleteHistoryRow(
                            cornerRadius: cardStyle.swipeCornerRadius,
                            onDelete: {
                                deleteHistory(itemId: item.id)
                            }
                        ) {
                            HistoryRow(
                                item: item,
                                cardStyle: cardStyle
                            )
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                    }
                }
                .animation(.snappy(duration: 0.34, extraBounce: 0.08), value: history.map(\.id))
            }
        }
    }

}

private extension GlassCardStyle {
    var swipeCornerRadius: CGFloat {
        switch self {
        case .hero: return StyleKit.Radius.hero
        case .standard: return StyleKit.Radius.card
        case .compact: return StyleKit.Radius.compact
        }
    }
}

// MARK: - History Row UI
private struct SwipeToDeleteHistoryRow<Content: View>: View {
    let cornerRadius: CGFloat
    let onDelete: () -> Void
    let content: Content

    @State private var offsetX: CGFloat = 0
    @State private var isDeleting = false

    private let maxSwipeDistance: CGFloat = 170
    private let deleteThreshold: CGFloat = 88

    init(
        cornerRadius: CGFloat,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteBackground
            content
                .offset(x: offsetX)
                .contentShape(Rectangle())
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .simultaneousGesture(swipeGesture)
    }

    private var deleteBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.red.opacity(0.84))
            .overlay(alignment: .trailing) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Löschen")
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.trailing, 18)
                .opacity(min(1, max(0, -offsetX / deleteThreshold)))
            }
            .opacity(offsetX < -6 ? 1 : 0)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard !isDeleting else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offsetX = swipeOffset(for: value.translation.width)
            }
            .onEnded { value in
                guard !isDeleting else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.snappy(duration: 0.26, extraBounce: 0.04)) {
                        offsetX = 0
                    }
                    return
                }
                let projected = min(value.translation.width, value.predictedEndTranslation.width)
                if projected <= -deleteThreshold || offsetX <= -deleteThreshold {
                    isDeleting = true
                    withAnimation(.smooth(duration: 0.18)) {
                        offsetX = -(maxSwipeDistance + 20)
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        onDelete()
                    }
                } else {
                    withAnimation(.snappy(duration: 0.26, extraBounce: 0.05)) {
                        offsetX = 0
                    }
                }
            }
    }

    private func swipeOffset(for translation: CGFloat) -> CGFloat {
        let leftOnly = min(0, translation)
        if leftOnly >= -maxSwipeDistance {
            return leftOnly
        }

        // Resist over-drag so the gesture tracks smoothly instead of hard-stopping.
        let overshoot = abs(leftOnly) - maxSwipeDistance
        let resisted = maxSwipeDistance + (overshoot * 0.22)
        return -resisted
    }
}

private struct HistoryRow: View {
    let item: MainView.HistoryItem
    let cardStyle: GlassCardStyle
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        GlassCard(style: cardStyle) {
            HStack(alignment: .center, spacing: 12) {
                artwork
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.trackName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                        .lineLimit(1)
                    Text(item.artistName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(StyleKit.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let name = item.playlistName, !name.isEmpty {
                            Text(name)
                        } else {
                            Text("Playlist")
                        }
                        Text("·")
                        Text(formattedDate(item.date))
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textMuted)
                    .lineLimit(1)
                }
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: item.status == "success" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(StyleKit.historyStatusColor(item.status))
                        .font(.system(size: 18, weight: .semibold))
                }
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
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(StyleKit.surfaceStrong)
            Image(systemName: "music.note")
                .foregroundStyle(StyleKit.textMuted)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Gestern"
        }
        return Self.dateFormatter.string(from: date)
    }
}

#Preview {
    MainView()
}
