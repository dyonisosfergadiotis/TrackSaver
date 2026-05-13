import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

struct MainView: View {
    @Environment(\.scenePhase) private var scenePhase
    let presentation: TrackSaverPresentationStyle

    // MARK: - Data Model
    // Local history model persisted per Spotify user in shared defaults.
    struct HistoryItem: Identifiable, Codable {
        let id: UUID
        let trackName: String
        let artistName: String
        let artworkURL: String?
        let trackURI: String?
        let date: Date
        let status: String // "success" | "fail"
        let playlistName: String?

        nonisolated init(
            id: UUID = UUID(),
            trackName: String,
            artistName: String,
            artworkURL: String?,
            trackURI: String? = nil,
            date: Date,
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

        nonisolated init(entry: SharedDefaults.HistoryEntry) {
            self.init(
                id: entry.id,
                trackName: entry.trackName,
                artistName: entry.artistName,
                artworkURL: entry.artworkURL,
                trackURI: entry.trackURI,
                date: entry.date,
                status: entry.status,
                playlistName: entry.playlistName
            )
        }

        var spotifyAppURL: URL? {
            let trimmedURI = (trackURI ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedURI.isEmpty else { return nil }
            return URL(string: trimmedURI)
        }

        var spotifyWebURL: URL? {
            let trimmedURI = (trackURI ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedURI.hasPrefix("spotify:track:") {
                let trackID = String(trimmedURI.dropFirst("spotify:track:".count))
                if !trackID.isEmpty {
                    return URL(string: "https://open.spotify.com/track/\(trackID)")
                }
            }
            return URL(string: trimmedURI)
        }

        var spotifyURL: URL? {
            spotifyWebURL ?? spotifyAppURL
        }
    }

    // MARK: - Storage & UI State
    @AppStorage("AccountUserId", store: SharedDefaults.store) private var accountUserId: String = ""
    @AppStorage("AccountDisplayName", store: SharedDefaults.store) private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL", store: SharedDefaults.store) private var accountAvatarURL: String = ""
    @AppStorage("DefaultPlaylistId", store: SharedDefaults.store) private var defaultPlaylistId: String = ""

    @State private var history: [HistoryItem] = []
    @State private var playlists: [SpotifyAPI.Playlist] = []
    @State private var selectedPlaylistId: String?

    private var selectedPlaylist: SpotifyAPI.Playlist? {
        playlists.first { $0.id == selectedPlaylistId }
    }

    private var selectedPlaylistSnapshot: SharedSelectedPlaylistSnapshot? {
        let snapshot = SharedDefaults.selectedPlaylistSnapshot()
        guard let snapshot else { return nil }
        let effectivePlaylistId = selectedPlaylistId ?? defaultPlaylistId
        guard snapshot.id == effectivePlaylistId || effectivePlaylistId.isEmpty else { return nil }
        return snapshot
    }

    // Bottom accessory + playlist picker sheet.
    @State private var showPlaylistPicker = false
    @State private var playlistPickerDetent: PresentationDetent = .medium
    @State private var showSettingsSheet = false
    @State private var isSaving = false
    @State private var isLoadingInitialData = false
    @State private var hasLoaded = false
    @State private var historyUserId: String = ""
    @State private var errorBannerMessage: String?
    @State private var errorBannerTask: Task<Void, Never>?
    @State private var successBannerMessage: String?
    @State private var successBannerTask: Task<Void, Never>?

    private let historyMutationAnimation: Animation = .snappy(duration: 0.36, extraBounce: 0.10)

    init(presentation: TrackSaverPresentationStyle = .standard) {
        self.presentation = presentation
    }

    private var isMenuBarPopover: Bool {
        presentation == .menuBarPopover
    }

    private var automaticAuthenticationUI: KeychainStore.AuthenticationUIBehavior {
        isMenuBarPopover ? .fail : .allow
    }

    private var popoverHorizontalInset: CGFloat {
        isMenuBarPopover ? 16 : 20
    }

    private var popoverHistoryHorizontalInset: CGFloat {
        isMenuBarPopover ? 8 : 20
    }

    private var historyRowSpacing: CGFloat {
        isMenuBarPopover ? 8 : 6.6
    }

    private var historyRowInset: CGFloat {
        isMenuBarPopover ? 5 : 3.3
    }

    private var historyEmptyRowInset: CGFloat {
        isMenuBarPopover ? 6 : 4
    }

    private var macAccountTitle: String {
        if let playlistName = selectedPlaylist?.name, !playlistName.isEmpty {
            return playlistName
        }

        if let snapshotName = selectedPlaylistSnapshot?.name, !snapshotName.isEmpty {
            return snapshotName
        }

        let trimmedDisplayName = accountDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayName.isEmpty {
            return trimmedDisplayName
        }

        let trimmedUserId = accountUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUserId.isEmpty {
            return trimmedUserId
        }

        return "TrackSaver"
    }

    private var macAccountSubtitle: String {
        let trimmedUserId = accountUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = accountDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedUserId.isEmpty, trimmedUserId != trimmedDisplayName {
            return trimmedUserId
        }

        if !trimmedDisplayName.isEmpty {
            return trimmedDisplayName
        }

        return "Spotify Account"
    }

    private var popoverHeaderTitle: String {
        let trimmedDisplayName = accountDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayName.isEmpty {
            return trimmedDisplayName
        }

        let trimmedUserId = accountUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUserId.isEmpty {
            return trimmedUserId
        }

        return "Spotify Account"
    }

    private var popoverHeaderSubtitle: String {
        if let playlistName = selectedPlaylist?.name, !playlistName.isEmpty {
            return playlistName
        }

        if let snapshotName = selectedPlaylistSnapshot?.name, !snapshotName.isEmpty {
            return snapshotName
        }

        return "Playlist wählen"
    }

    @ViewBuilder
    private var historyListContent: some View {
        #if os(macOS)
        if isMenuBarPopover {
            popoverHistoryContent
        } else {
            historyListBase
        }
        #else
        historyListBase
            .listRowSpacing(historyRowSpacing)
        #endif
    }

    private var historyListBase: some View {
        List {
            historySection
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .hideMacScrollbars()
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, isMenuBarPopover ? 0 : 108)
        .refreshable {
            await refreshHistoryFromCloud()
        }
        .overlay {
            if isLoadingInitialData {
                ProgressView("Lade Playlists…")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LiquidGlassPlate(
                            cornerRadius: 18,
                            tint: StyleKit.surface,
                            edgeTint: StyleKit.stroke,
                            glowColor: StyleKit.glassGlowWarm,
                            material: .thinMaterial,
                            shadowOpacity: 0.16,
                            shadowRadius: 9,
                            shadowY: 3
                        )
                    )
            }
        }
        .overlay(alignment: .top) {
            if !isMenuBarPopover, let errorBannerMessage {
                errorBanner(message: errorBannerMessage)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if !isMenuBarPopover, let successBannerMessage {
                successBanner(message: successBannerMessage)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var popoverHistoryContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                if history.isEmpty {
                    historyEmptyCard
                } else {
                    ForEach(history) { item in
                        HistoryRow(
                            item: item,
                            cardStyle: .compact,
                            presentation: presentation
                        )
                    }
                }
            }
            .padding(.horizontal, popoverHistoryHorizontalInset)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .hideMacScrollbars()
        .overlay {
            if isLoadingInitialData {
                ProgressView("Lade Playlists…")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LiquidGlassPlate(
                            cornerRadius: 18,
                            tint: StyleKit.surface,
                            edgeTint: StyleKit.stroke,
                            glowColor: StyleKit.glassGlowWarm,
                            material: .thinMaterial,
                            shadowOpacity: 0.16,
                            shadowRadius: 9,
                            shadowY: 3
                        )
                    )
            }
        }
    }

    var body: some View {
        Group {
            if isMenuBarPopover {
                popoverBody
            } else {
                standardBody
            }
        }
        #if !os(macOS)
        .sheet(isPresented: $showPlaylistPicker) {
            PlaylistSheetView(
                playlists: playlists,
                selectedId: $selectedPlaylistId,
                selectedPlaylist: selectedPlaylist,
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
            .presentationBackground(.clear)
            .presentationDetents([.medium, .large], selection: $playlistPickerDetent)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.resizes)
        }
        #endif
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.hidden)
        }
        .task {
            if !hasLoaded {
                CloudAccountSyncService.shared.refreshFromCloud()
                SharedDefaults.migrateDefaultPlaylistIdIfNeeded()
                await reloadData(
                    showInitialLoading: true,
                    forceHistoryReload: true,
                    authenticationUI: automaticAuthenticationUI
                )
            }
        }
        .onChange(of: accountUserId) { _, newUserId in
            guard !newUserId.isEmpty, newUserId != historyUserId else { return }
            historyUserId = newUserId
            SharedDefaults.migrateLegacyHistoryIfNeeded(for: newUserId)
            loadHistoryFromStorage(for: newUserId)
            syncHistoryFromCloud(for: newUserId)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: SharedDefaults.historyDidChangeNotification)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let changedUserId = notification.userInfo?[SharedDefaults.historyDidChangeUserIdKey] as? String else {
                return
            }
            let effectiveUserId = historyUserId.isEmpty ? accountUserId : historyUserId
            guard !effectiveUserId.isEmpty, changedUserId == effectiveUserId else { return }
            loadHistoryFromStorage(for: effectiveUserId, animated: true)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: SharedDefaults.historyRefreshRequestedNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            Task {
                await reloadData(
                    showInitialLoading: false,
                    forceHistoryReload: true,
                    authenticationUI: automaticAuthenticationUI
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, hasLoaded else { return }
            Task {
                CloudAccountSyncService.shared.refreshFromCloud()
                await reloadData(
                    showInitialLoading: false,
                    forceHistoryReload: true,
                    authenticationUI: automaticAuthenticationUI
                )
            }
        }
    }

    private var standardBody: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                historyListContent
            }
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(macAccountTitle)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TrackSaver")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(StyleKit.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
#if !os(macOS)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                playlistAccessory
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
#endif
        }
    }

    private var popoverBody: some View {
        ZStack {
            AppBackground(style: .menuBarPopover)

            VStack(spacing: 0) {
                popoverHeader
                    .padding(.horizontal, popoverHorizontalInset)
                    .padding(.top, 12)

                if let errorBannerMessage {
                    errorBanner(message: errorBannerMessage)
                        .padding(.horizontal, popoverHorizontalInset)
                        .padding(.top, 8)
                } else if let successBannerMessage {
                    successBanner(message: successBannerMessage)
                        .padding(.horizontal, popoverHorizontalInset)
                        .padding(.top, 8)
                }

                historyListContent
                    .padding(.top, 6)

                #if !os(macOS)
                popoverFooter
                    .padding(.horizontal, popoverHorizontalInset)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                #endif
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(StyleKit.strokeSoft.opacity(0.7), lineWidth: 1)
        }
    }

    // MARK: - Data Loading
    private func refreshPlaylists() async {
        await reloadData(
            showInitialLoading: false,
            forceHistoryReload: false,
            authenticationUI: .allow
        )
    }

    private func refreshHistoryFromCloud() async {
        let effectiveUserId = (historyUserId.isEmpty ? accountUserId : historyUserId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !effectiveUserId.isEmpty else { return }

        SharedDefaults.migrateLegacyHistoryIfNeeded(for: effectiveUserId)
        let syncedEntries = await CloudHistorySyncService.shared.syncHistory(for: effectiveUserId)
        applyHistoryEntries(syncedEntries, animated: true)
    }

    private func reloadData(
        showInitialLoading: Bool,
        forceHistoryReload: Bool,
        authenticationUI: KeychainStore.AuthenticationUIBehavior
    ) async {
        hasLoaded = true
        if showInitialLoading {
            isLoadingInitialData = true
        }
        defer {
            isLoadingInitialData = false
        }

        loadCachedHistoryIfAvailable(forceHistoryReload: forceHistoryReload)

        if authenticationUI == .fail &&
            !KeychainStore().hasAuthTokens(authenticationUI: authenticationUI) {
            return
        }

        do {
            try await SpotifyAPI.shared.refreshSessionIfNeeded(forceRefresh: true)
            async let meCall = SpotifyAPI.shared.fetchMe()
            async let playlistsCall = SpotifyAPI.shared.fetchPlaylists()
            let (me, playlistsResp) = try await (meCall, playlistsCall)
            let editablePlaylists = filterEditablePlaylists(playlistsResp, userId: me.id)
            playlists = editablePlaylists
            SharedDefaults.cachePlaylistNames(
                editablePlaylists.reduce(into: [String: String]()) { result, playlist in
                    result[playlist.id] = playlist.name
                }
            )

#if os(macOS)
            if !defaultPlaylistId.isEmpty, editablePlaylists.contains(where: { $0.id == defaultPlaylistId }) {
                selectedPlaylistId = defaultPlaylistId
            } else {
                selectedPlaylistId = nil
            }
#else
            if !defaultPlaylistId.isEmpty, editablePlaylists.contains(where: { $0.id == defaultPlaylistId }) {
                selectedPlaylistId = defaultPlaylistId
            } else if let existing = selectedPlaylistId, editablePlaylists.contains(where: { $0.id == existing }) {
                selectedPlaylistId = existing
            } else if let fallback = editablePlaylists.first?.id {
                selectedPlaylistId = fallback
            } else {
                selectedPlaylistId = nil
            }
#endif

            if forceHistoryReload || historyUserId != me.id {
                historyUserId = me.id
                SharedDefaults.migrateLegacyHistoryIfNeeded(for: me.id)
                loadHistoryFromStorage(for: me.id)
                let syncedEntries = await CloudHistorySyncService.shared.syncHistory(for: me.id)
                applyHistoryEntries(syncedEntries, animated: true)
            }

            if let effectiveSelectedPlaylist = editablePlaylists.first(where: { $0.id == defaultPlaylistId }) {
                SharedDefaults.cacheSelectedPlaylist(
                    id: effectiveSelectedPlaylist.id,
                    name: effectiveSelectedPlaylist.name,
                    description: effectiveSelectedPlaylist.description,
                    artworkURL: effectiveSelectedPlaylist.images?.first?.url
                )
                #if os(iOS)
                CloudAccountSyncService.shared.syncConfigurationFromLocal()
                #endif
            }
        } catch {
            handleAPIError(error)
        }
    }

    private func loadCachedHistoryIfAvailable(forceHistoryReload: Bool) {
        let cachedUserId = SharedDefaults.preferredHistoryUserId(
            fallbackUserId: historyUserId.isEmpty ? nil : historyUserId
        )
        guard !cachedUserId.isEmpty else { return }
        guard forceHistoryReload || history.isEmpty || historyUserId != cachedUserId else { return }
        historyUserId = cachedUserId
        SharedDefaults.migrateLegacyHistoryIfNeeded(for: cachedUserId)
        loadHistoryFromStorage(for: cachedUserId)
        syncHistoryFromCloud(for: cachedUserId)
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
        SharedDefaults.cachePlaylistName(playlist.name, for: playlist.id)
        SharedDefaults.cacheSelectedPlaylist(
            id: playlist.id,
            name: playlist.name,
            description: playlist.description,
            artworkURL: playlist.images?.first?.url
        )
        CloudAccountSyncService.shared.syncConfigurationFromLocal()
    }

    // Handles auth errors by clearing tokens and returning to login.
    private func handleAPIError(_ error: Error) {
        if let apiError = error as? SpotifyAPIError {
            switch apiError {
            case .unauthorized:
#if os(macOS)
                showErrorBanner("Öffne TrackSaver auf deinem iPhone und prüfe dort die Spotify-Anmeldung.")
#else
                CloudAccountSyncService.shared.logout()
#endif
            default:
                showErrorBanner(apiError.errorDescription ?? error.localizedDescription)
            }
            return
        }
        showErrorBanner(error.localizedDescription)
    }

    // MARK: - Local History
    private func loadHistoryFromStorage(for userId: String, animated: Bool = false) {
        applyHistoryEntries(SharedDefaults.loadHistoryEntries(for: userId), animated: animated)
    }

    private func syncHistoryFromCloud(for userId: String) {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserId.isEmpty else { return }

        Task {
            let syncedEntries = await CloudHistorySyncService.shared.syncHistory(for: trimmedUserId)
            await MainActor.run {
                let effectiveUserId = historyUserId.isEmpty ? accountUserId : historyUserId
                guard effectiveUserId == trimmedUserId else { return }
                applyHistoryEntries(syncedEntries, animated: true)
            }
        }
    }

    private func applyHistoryEntries(_ entries: [SharedDefaults.HistoryEntry], animated: Bool) {
        let items = entries.map(HistoryItem.init(entry:))
        if animated {
            withAnimation(historyMutationAnimation) {
                history = items
            }
        } else {
            history = items
        }
    }

    private func deleteHistory(itemId: UUID) {
        let effectiveUserId = historyUserId.isEmpty ? accountUserId : historyUserId
        guard !effectiveUserId.isEmpty else { return }
        SharedDefaults.stageHistoryDeletion(itemId, for: effectiveUserId)
        loadHistoryFromStorage(for: effectiveUserId, animated: true)
        Task {
            let syncedEntries = await CloudHistorySyncService.shared.syncHistory(for: effectiveUserId)
            await MainActor.run {
                applyHistoryEntries(syncedEntries, animated: true)
            }
        }
    }

    // MARK: - Save Current Track
    private func saveCurrentTrack() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            guard let playlistId = selectedPlaylistId else {
#if os(macOS)
                showErrorBanner("Wähle die Ziel-Playlist in TrackSaver auf deinem iPhone aus.")
#else
                showErrorBanner("Bitte zuerst eine Playlist auswählen.")
#endif
                return
            }
            let targetPlaylistName = selectedPlaylist?.name ?? SharedDefaults.playlistName(for: playlistId)
            do {
                // The Spotify API call handles duplicate/no-playback checks.
                let result = try await TrackSaveService.saveCurrentTrack(
                    playlistId: playlistId,
                    playlistName: targetPlaylistName
                )
                if !result.historyUserId.isEmpty {
                    historyUserId = result.historyUserId
                    loadHistoryFromStorage(for: result.historyUserId, animated: true)
                }
                showSuccessBanner(TrackSaveService.successMessage(for: result.playlistName))
                await NotificationHelper.notify(
                    title: "\(result.response.trackName) von \(result.response.artistName)",
                    body: TrackSaveService.successMessage(for: result.playlistName),
                    artworkURLString: result.response.artworkURL
                )
            } catch {
                if let apiError = error as? SpotifyAPIError {
                    switch apiError {
                    case .noCurrentTrack:
                        showErrorBanner("Es läuft gerade kein Song.")
                        await NotificationHelper.notify(
                            title: "Kein Track",
                            body: "Es läuft gerade kein Song"
                        )
                        return
                    case .duplicateTrack(let trackName, let artistName, let artworkURL):
                        let playlistName = SharedDefaults.playlistName(for: playlistId) ?? targetPlaylistName
                        showErrorBanner(TrackSaveService.duplicateBannerMessage(for: playlistName))
                        await NotificationHelper.notify(
                            title: "\(trackName) von \(artistName)",
                            body: TrackSaveService.duplicateMessage(for: playlistName),
                            artworkURLString: artworkURL
                        )
                        return
                    default:
                        break
                    }
                }
                handleAPIError(error)
            }
        }
    }

    private func showErrorBanner(_ message: String) {
        successBannerTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            successBannerMessage = nil
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

    private func showSuccessBanner(_ message: String) {
        errorBannerTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            errorBannerMessage = nil
            successBannerMessage = message
        }
        successBannerTask?.cancel()
        successBannerTask = Task {
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    successBannerMessage = nil
                }
            }
        }
    }
}

private extension MainView {
    func successBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LiquidGlassPlate(
                cornerRadius: 18,
                tint: Color.green.opacity(0.44),
                edgeTint: Color.white.opacity(0.20),
                glowColor: StyleKit.glassGlowWarm,
                material: .thinMaterial,
                shadowOpacity: 0.24,
                shadowRadius: 10,
                shadowY: 4
            )
        )
    }

    func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LiquidGlassPlate(
                cornerRadius: 18,
                tint: Color.red.opacity(0.44),
                edgeTint: Color.white.opacity(0.20),
                glowColor: StyleKit.glassGlowWarm,
                material: .thinMaterial,
                shadowOpacity: 0.24,
                shadowRadius: 10,
                shadowY: 4
            )
        )
    }

    var popoverHeader: some View {
        GlassCard(style: .compact) {
            HStack(spacing: 12) {
                popoverHeaderArtwork
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(popoverHeaderTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(popoverHeaderSubtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(StyleKit.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                Button {
                    Task { await refreshPlaylists() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StyleKit.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(StyleKit.surfaceSoft)
                        )
                }
                .buttonStyle(.plain)

#if !os(macOS)
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StyleKit.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(StyleKit.surfaceSoft)
                        )
                }
                .buttonStyle(.plain)
#endif
            }
            .frame(minHeight: 34)
        }
        .overlay {
            selectedPlaylistCardBorder
        }
    }

    @ViewBuilder
    var popoverHeaderArtwork: some View {
        if let url = URL(string: accountAvatarURL), !accountAvatarURL.isEmpty {
            RemoteImage(url: url) {
                popoverHeaderFallbackArtwork
            }
            .scaledToFill()
        } else {
            popoverHeaderFallbackArtwork
        }
    }

    var popoverHeaderFallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(StyleKit.surfaceStrong)
            Image(systemName: "music.note.list")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StyleKit.accent)
        }
    }

    var popoverFooter: some View {
        Button {
            playlistPickerDetent = .medium
            showPlaylistPicker = true
        } label: {
            GlassCard(style: .compact) {
                HStack(spacing: 12) {
                    playlistAccessoryArtwork
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedPlaylistDisplayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(StyleKit.textPrimary)
                            .lineLimit(1)

                        Text(selectedPlaylistDisplayDescription)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(StyleKit.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(StyleKit.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 34)
            }
        }
        .buttonStyle(.plain)
        .overlay {
            selectedPlaylistCardBorder
        }
    }

    // MARK: - Bottom Accessory
    var playlistAccessory: some View {
        Button {
            playlistPickerDetent = .medium
            showPlaylistPicker = true
        } label: {
            GlassCard(style: .standard) {
                HStack(spacing: 12) {
                    playlistAccessoryArtwork
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(selectedPlaylist?.name ?? "Playlists")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(StyleKit.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(selectedPlaylistSubtitle ?? "Tippen zum Wechseln")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(StyleKit.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var playlistAccessoryArtwork: some View {
        let artworkURLString = selectedPlaylist?.images?.first?.url ?? selectedPlaylistSnapshot?.artworkURL ?? ""
        if let url = URL(string: artworkURLString), !artworkURLString.isEmpty {
            RemoteImage(url: url) { playlistAccessoryFallbackArtwork }
                .scaledToFill()
                .id(url.absoluteString)
        } else {
            playlistAccessoryFallbackArtwork
        }
    }

    var playlistAccessoryFallbackArtwork: some View {
        ZStack {
            LiquidGlassPlate(
                cornerRadius: 11,
                tint: StyleKit.surfaceStrong,
                edgeTint: StyleKit.stroke,
                glowColor: StyleKit.glassGlowWarm,
                material: .thinMaterial,
                shadowOpacity: 0.10,
                shadowRadius: 5,
                shadowY: 2
            )
            Image(systemName: "music.note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StyleKit.textMuted)
        }
    }

    var selectedPlaylistSubtitle: String? {
        let trimmed = (selectedPlaylist?.description ?? selectedPlaylistSnapshot?.description ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var selectedPlaylistDisplayName: String {
        if let name = selectedPlaylist?.name, !name.isEmpty {
            return name
        }
        if let snapshotName = selectedPlaylistSnapshot?.name, !snapshotName.isEmpty {
            return snapshotName
        }
        return "Gewählte Playlist"
    }

    var selectedPlaylistDisplayDescription: String {
        if let subtitle = selectedPlaylistSubtitle {
            return subtitle
        }
        return "Wird über iCloud vom iPhone synchronisiert."
    }

    var selectedPlaylistCardBorder: some View {
        RoundedRectangle(cornerRadius: StyleKit.Radius.compact, style: .continuous)
            .stroke(StyleKit.accent.opacity(0.62), lineWidth: 1.2)
            .shadow(color: StyleKit.accent.opacity(0.26), radius: 10, x: 0, y: 0)
    }

    // MARK: - History UI
    var historySection: some View {
        Section {
            if history.isEmpty {
                historyEmptyCard
                .listRowInsets(
                    EdgeInsets(
                        top: historyEmptyRowInset,
                        leading: popoverHorizontalInset,
                        bottom: historyEmptyRowInset,
                        trailing: popoverHorizontalInset
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(Array(history.enumerated()), id: \.element.id) { _, item in
                    let cardStyle: GlassCardStyle = .compact
                    HistoryRow(
                        item: item,
                        cardStyle: cardStyle,
                        presentation: presentation
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: isMenuBarPopover ? 4 : historyRowInset,
                            leading: popoverHorizontalInset,
                            bottom: isMenuBarPopover ? 4 : historyRowInset,
                            trailing: popoverHorizontalInset
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteHistory(itemId: item.id)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
                .animation(.snappy(duration: 0.34, extraBounce: 0.08), value: history.count)
            }
        } header: {
            EmptyView()
        }
    }

    private var historyEmptyCard: some View {
        GlassCard(style: .compact) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StyleKit.accent)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(StyleKit.surfaceSoft)
                    )

                Text(isMenuBarPopover
                     ? "Noch nichts gespeichert. Rechtsklick speichert sofort, Linksklick zeigt die Historie."
                     : "Noch nichts gespeichert. Nutze „Sichern“ in der Leiste unten.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
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
    @Environment(\.openURL) private var openURL
    let item: MainView.HistoryItem
    let cardStyle: GlassCardStyle
    let presentation: TrackSaverPresentationStyle
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

    private var isMenuBarPopover: Bool {
        presentation == .menuBarPopover
    }

    private var isFailedItem: Bool {
        item.status != "success"
    }

    private var content: some View {
        GlassCard(style: cardStyle) {
            HStack(alignment: .center, spacing: isMenuBarPopover ? 10 : 12) {
                artwork
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.trackName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                        .lineLimit(1)

                    Text(item.artistName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(StyleKit.textSecondary)
                        .lineLimit(1)

                    Group {
                        #if os(macOS)
                        if let name = item.playlistName, !name.isEmpty {
                            Text(name)
                                .lineLimit(1)
                        } else {
                            Text("Playlist")
                        }
                        #else
                        HStack(spacing: 4) {
                            if let name = item.playlistName, !name.isEmpty {
                                Text(name)
                                    .lineLimit(1)
                            } else {
                                Text("Playlist")
                            }

                            Text("·")
                            Text(formattedDate(item.date))
                                .lineLimit(1)
                        }
                        #endif
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()

                if item.spotifyURL != nil {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(StyleKit.accent)
                        .font(.system(size: 13, weight: .semibold))
                        .accessibilityLabel(Text("In Spotify öffnen"))
                        .padding(.trailing, isFailedItem ? 2 : 0)
                }

                if isFailedItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(StyleKit.historyStatusColor(item.status))
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        Group {
            if let spotifyURL = item.spotifyURL {
                #if os(iOS)
                Button {
                    openSpotifyLink()
                } label: {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
                #else
                Link(destination: spotifyURL) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
                #endif
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        let time = Self.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) {
            return time
        }
        if calendar.isDateInYesterday(date) {
            return "Gestern · \(time)"
        }
        return "\(Self.dateFormatter.string(from: date)) · \(time)"
    }

    #if os(iOS)
    private func openSpotifyLink() {
        if let appURL = item.spotifyAppURL {
            openURL(appURL) { accepted in
                guard !accepted, let webURL = item.spotifyWebURL else { return }
                openURL(webURL)
            }
            return
        }

        if let webURL = item.spotifyWebURL {
            openURL(webURL)
        }
    }
    #endif
}

#if !os(macOS)
#Preview {
    MainView()
}
#endif

#if os(macOS)
private struct MacScrollbarsHiddenConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(from: nsView)
        }
    }

    private func configure(from view: NSView) {
        guard let scrollView = enclosingScrollView(for: view) else { return }
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
    }

    private func enclosingScrollView(for view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let node = current {
            if let scrollView = node as? NSScrollView {
                return scrollView
            }
            current = node.superview
        }
        return nil
    }
}
#endif

private extension View {
    @ViewBuilder
    func hideMacScrollbars() -> some View {
        #if os(macOS)
        background(MacScrollbarsHiddenConfigurator())
        #else
        self
        #endif
    }
}
