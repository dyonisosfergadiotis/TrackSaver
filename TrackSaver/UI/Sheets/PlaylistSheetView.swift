import SwiftUI

struct PlaylistSheetView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    static let minimizedDetentHeight: CGFloat = 100

    let playlists: [SpotifyAPI.Playlist]
    @Binding var selectedId: String?
    let selectedPlaylist: SpotifyAPI.Playlist?
    let isLoadingPlaylists: Bool
    @Binding var detent: PresentationDetent
    var allowsCollapse: Bool = true
    var onSelect: @Sendable (_ playlist: SpotifyAPI.Playlist) async -> Void
    var onRefresh: @Sendable () async -> Void

    @State private var query: String = ""
    @State private var isSwitchingPlaylist = false
    @FocusState private var isToolbarSearchFocused: Bool

    private var currentSelected: SpotifyAPI.Playlist? {
        playlists.first(where: { $0.id == selectedId }) ?? selectedPlaylist
    }

    private var selectablePlaylists: [SpotifyAPI.Playlist] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedPlaylists: [SpotifyAPI.Playlist]

        if normalizedQuery.isEmpty {
            matchedPlaylists = playlists
        } else {
            matchedPlaylists = playlists.filter { playlist in
                if playlist.name.localizedCaseInsensitiveContains(normalizedQuery) {
                    return true
                }

                let description = playlist.description ?? ""
                return description.localizedCaseInsensitiveContains(normalizedQuery)
            }
        }

        guard let selectedId else {
            return alphabeticallySortedPlaylists(matchedPlaylists)
        }

        return alphabeticallySortedPlaylists(
            matchedPlaylists.filter { $0.id != selectedId }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                selectedPlaylistCard
                    .padding(.horizontal, 20)

                expandedBody
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.clear)
            .navigationTitle("Playlists")
            .playlistSheetInlineNavigationBarTitleDisplayMode()
            .toolbar { playlistSheetToolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var playlistSheetToolbarContent: some ToolbarContent {
#if os(macOS)
        ToolbarItem(placement: .principal) {
            searchToolbarField
                .frame(minWidth: 260)
        }

        ToolbarItem(placement: .primaryAction) {
            refreshToolbarButton
        }

        if isToolbarSearchFocused {
            ToolbarItem(placement: .automatic) {
                closeSearchToolbarButton
            }
        }
#else
        ToolbarItem(placement: .topBarTrailing) {
            refreshToolbarButton
        }

        ToolbarItem(placement: .bottomBar) {
            searchToolbarField
        }

        if isToolbarSearchFocused {
            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                closeSearchToolbarButton
            }
        }
#endif
    }

    private var refreshToolbarButton: some View {
        Button {
            Task {
                await onRefresh()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StyleKit.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var searchToolbarField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(StyleKit.accent)
                .padding(.leading, 10)

            TextField("Playlist suchen", text: $query)
                .focused($isToolbarSearchFocused)
                .playlistSheetSearchInputBehavior()
                .tint(StyleKit.accent)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(StyleKit.textMuted)
                }
                .padding(.trailing, 10)
                .buttonStyle(.plain)
                .accessibilityLabel("Suche leeren")
            }
        }
    }

    private var closeSearchToolbarButton: some View {
        Button {
            closeSearchFromToolbar()
        } label: {
            Image(systemName: "xmark")
                .foregroundStyle(StyleKit.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Suche schließen")
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Playlists")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(StyleKit.textPrimary)
            }

            Spacer(minLength: 12)
        }
    }

    private var selectedPlaylistCard: some View {
        GlassCard(style: .compact) {
            HStack(spacing: 12) {
                compactArtwork
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(currentSelected?.name ?? "Playlists")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(StyleKit.textPrimary)
                            .lineLimit(1)

                        Text(selectedPlaylistDescription)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(StyleKit.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)

                    if currentSelected != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(StyleKit.accent)
                    }
                }
            }
        }
        .overlay {
            playlistCardContrastOverlay
        }
        .overlay {
            if currentSelected != nil {
                RoundedRectangle(cornerRadius: StyleKit.Radius.compact, style: .continuous)
                    .stroke(StyleKit.accent.opacity(0.55), lineWidth: 1.2)
                    .shadow(color: StyleKit.accent.opacity(0.28), radius: 10, x: 0, y: 0)
                    .shadow(color: StyleKit.glassGlow.opacity(0.22), radius: 18, x: 0, y: 0)
            }
        }
    }

    @ViewBuilder
    private var expandedBody: some View {
        if isLoadingPlaylists {
            VStack(spacing: 10) {
                ProgressView()
                Text("Playlists werden geladen…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 32)
        } else if playlists.isEmpty || selectablePlaylists.isEmpty {
            emptyState
        } else {
            playlistList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GlassCard(style: .compact) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(query.isEmpty ? "Keine weiteren Playlists gefunden." : "Keine Treffer für deine Suche.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)

                    Text(
                        query.isEmpty
                            ? "Wenn du nur eine bearbeitbare Playlist hast, bleibt sie oben als ausgewählte Playlist stehen."
                            : "Passe den Suchbegriff an oder aktualisiere die Liste."
                    )
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)

                    if query.isEmpty {
                        Button {
                            createPlaylistInSpotify()
                        } label: {
                            Label("Neue Playlist in Spotify anlegen", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.glassProminent)
                        .tint(StyleKit.accent)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var playlistList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(query.isEmpty ? "Weitere Playlists" : "Suchergebnisse")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textSecondary)

                    Spacer()

                    Text("\(selectablePlaylists.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textMuted)
                }
                .padding(.horizontal, 20)

                LazyVStack(spacing: 15) {
                    ForEach(selectablePlaylists) { playlist in
                        Button {
                            Task {
                                isSwitchingPlaylist = true
                                defer { isSwitchingPlaylist = false }
                                await onSelect(playlist)
                            }
                        } label: {
                            playlistRow(playlist)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSwitchingPlaylist)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 104)
        }
        .refreshable {
            await onRefresh()
        }
    }

    private func playlistRow(_ playlist: SpotifyAPI.Playlist) -> some View {
        GlassCard(style: .compact) {
            HStack(spacing: 12) {
                playlistArtwork(playlist, isCompact: false)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                        .lineLimit(1)

                    Text(playlistSubtitle(playlist) ?? "Tippen, um diese Playlist aktiv zu setzen.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(StyleKit.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.left.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(StyleKit.accent)
            }
        }
        .overlay {
            playlistCardContrastOverlay
        }
    }

    @ViewBuilder
    private var playlistCardContrastOverlay: some View {
        if colorScheme != .dark {
            RoundedRectangle(cornerRadius: StyleKit.Radius.compact, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: StyleKit.Radius.compact, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            StyleKit.strokeStrong.opacity(0.34),
                            StyleKit.stroke.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private var compactArtwork: some View {
        if let urlString = currentSelected?.images?.first?.url, let url = URL(string: urlString) {
            RemoteImage(url: url) { artworkFallback(isCompact: true) }
                .scaledToFill()
                .id(url.absoluteString)
        } else {
            artworkFallback(isCompact: true)
        }
    }

    @ViewBuilder
    private func playlistArtwork(_ playlist: SpotifyAPI.Playlist, isCompact: Bool) -> some View {
        if let urlString = playlist.images?.first?.url, let url = URL(string: urlString) {
            RemoteImage(url: url) { artworkFallback(isCompact: isCompact) }
                .scaledToFill()
        } else {
            artworkFallback(isCompact: isCompact)
        }
    }

    private func artworkFallback(isCompact: Bool) -> some View {
        ZStack {
            LiquidGlassPlate(
                cornerRadius: isCompact ? 12 : 14,
                tint: StyleKit.surfaceStrong,
                edgeTint: StyleKit.stroke,
                glowColor: StyleKit.glassGlowWarm,
                material: .thinMaterial,
                shadowOpacity: 0.10,
                shadowRadius: 5,
                shadowY: 2
            )

            Image(systemName: "music.note")
                .font(.system(size: isCompact ? 14 : 18, weight: .semibold))
                .foregroundStyle(StyleKit.textMuted)
        }
    }

    private var selectedPlaylistDescription: String {
        if let currentSelected, let subtitle = playlistSubtitle(currentSelected) {
            return subtitle
        }

        if currentSelected != nil {
            return "Diese Playlist wird für neue Saves verwendet."
        }

        return "Wähle eine Playlist aus, in die neue Tracks gespeichert werden."
    }

    private func playlistSubtitle(_ playlist: SpotifyAPI.Playlist) -> String? {
        let trimmed = (playlist.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func alphabeticallySortedPlaylists(_ playlists: [SpotifyAPI.Playlist]) -> [SpotifyAPI.Playlist] {
        playlists.sorted {
            let leftName = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let rightName = $1.name.trimmingCharacters(in: .whitespacesAndNewlines)

            let comparison = leftName.localizedCaseInsensitiveCompare(rightName)
            if comparison == .orderedSame {
                return $0.id < $1.id
            }

            return comparison == .orderedAscending
        }
    }

    private func createPlaylistInSpotify() {
        guard let url = URL(string: "https://open.spotify.com/collection/playlists") else { return }
        openURL(url)
    }

    private func closeSearchFromToolbar() {
        isToolbarSearchFocused = false
    }
}

private extension View {
    @ViewBuilder
    func playlistSheetInlineNavigationBarTitleDisplayMode() -> some View {
#if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }

    @ViewBuilder
    func playlistSheetSearchInputBehavior() -> some View {
#if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
#else
        self
#endif
    }
}

#if !os(macOS)
#Preview("PlaylistSheetView") {
    struct PreviewHost: View {
        @State private var selectedId: String? = "1"
        @State private var detent: PresentationDetent = .medium
        @State private var showSheet: Bool = true

        var samplePlaylists: [SpotifyAPI.Playlist] {
            [
                .init(
                    id: "1",
                    name: "Daily Mix",
                    description: "Handpicked for you",
                    images: [.init(url: "https://via.placeholder.com/150", height: 150, width: 150)],
                    owner: .init(id: "Preview Owner"),
                    collaborative: false
                ),
                .init(
                    id: "2",
                    name: "Top Hits",
                    description: "Hot right now",
                    images: [.init(url: "https://via.placeholder.com/150", height: 150, width: 150)],
                    owner: .init(id: "Preview Owner"),
                    collaborative: false
                ),
                .init(
                    id: "3",
                    name: "Chill Vibes",
                    description: "Relax and unwind",
                    images: [.init(url: "https://via.placeholder.com/150", height: 150, width: 150)],
                    owner: .init(id: "Preview Owner"),
                    collaborative: false
                )
            ]
        }

        var body: some View {
            ZStack {
                AppBackground()
                Text("Host View")
                    .foregroundStyle(StyleKit.textSecondary)
            }
            .sheet(isPresented: $showSheet) {
                PlaylistSheetView(
                    playlists: samplePlaylists,
                    selectedId: $selectedId,
                    selectedPlaylist: samplePlaylists.first,
                    isLoadingPlaylists: false,
                    detent: $detent,
                    allowsCollapse: false,
                    onSelect: { _ in },
                    onRefresh: {}
                )
                .presentationBackground(.clear)
                .presentationDetents([.medium, .large], selection: $detent)
            }
        }
    }

    return PreviewHost()
}
#endif
