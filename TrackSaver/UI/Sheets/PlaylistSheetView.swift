import SwiftUI

private struct SearchableWhenExpandedModifier: ViewModifier {
    let isExpanded: Bool
    @Binding var query: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isExpanded {
            content.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        } else {
            content
        }
    }
}

struct PlaylistSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    static let minimizedDetentHeight: CGFloat = 100

    // MARK: - Inputs
    let playlists: [SpotifyAPI.Playlist]
    @Binding var selectedId: String?
    let selectedPlaylist: SpotifyAPI.Playlist?
    let isRefreshing: Bool
    let isLoadingPlaylists: Bool
    @Binding var detent: PresentationDetent
    var allowsCollapse: Bool = true
    var onSelect: @Sendable (_ playlist: SpotifyAPI.Playlist) async -> Void
    var onRefresh: @Sendable () async -> Void

    // Local search state
    @State private var query: String = ""
    @State private var isSwitchingPlaylist = false

    // Convenience flags for UI states
    private var isMinimized: Bool {
        allowsCollapse && detent == .height(Self.minimizedDetentHeight)
    }

    private var currentSelected: SpotifyAPI.Playlist? {
        playlists.first(where: { $0.id == selectedId }) ?? selectedPlaylist
    }

    private var filtered: [SpotifyAPI.Playlist] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return playlists }
        return playlists.filter { playlist in
            if playlist.name.localizedCaseInsensitiveContains(trimmedQuery) { return true }
            let description = playlist.description ?? ""
            return description.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var selectablePlaylists: [SpotifyAPI.Playlist] {
        filtered.filter { $0.id != selectedId }
    }

    private var detentAnimation: Animation {
        .interactiveSpring(response: 0.50, dampingFraction: 0.90, blendDuration: 0.24)
    }

    var body: some View {
        NavigationStack {
            sheetContent
                .animation(detentAnimation, value: isMinimized)
                .navigationTitle(isMinimized ? "" : "Playlist wählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(isMinimized ? .hidden : .visible, for: .navigationBar)
                .modifier(SearchableWhenExpandedModifier(isExpanded: !isMinimized, query: $query))
        }
    }

    // MARK: - Layout
    private var sheetContent: some View {
        ZStack(alignment: .top) {
            AppBackground()

            VStack(spacing: 0) {
                if isMinimized {
                    minimizedHeader
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 6)
                } else {
                    expandedHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    expandedBody
                }
            }
        }
    }

    // MARK: - Header
    private var minimizedHeader: some View {
        Button {
            toggleDetent()
        } label: {
            HStack(spacing: 12) {
                compactArtwork
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentSelected?.name ?? "Playlist wählen")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let compactDescription {
                        Text(compactDescription)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
    }

    private var expandedHeader: some View {
        Button {
            if allowsCollapse {
                toggleDetent()
            } else {
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                compactArtwork
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentSelected?.name ?? "Playlist wählen")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let compactDescription {
                        Text(compactDescription)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: allowsCollapse ? "chevron.down" : "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(allowsCollapse ? Color.white.opacity(0.86) : StyleKit.accent)
                    .padding(9)
                    .background(
                        Circle()
                            .fill(allowsCollapse ? Color.white.opacity(0.10) : StyleKit.accent.opacity(0.14))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Expanded Body
    @ViewBuilder
    private var expandedBody: some View {
        if isLoadingPlaylists {
            VStack(spacing: 10) {
                ProgressView()
                Text("Playlists werden geladen…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 20)
        } else if playlists.isEmpty || selectablePlaylists.isEmpty {
            emptyState
        } else {
            playlistList
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 12)),
                        removal: .opacity.combined(with: .offset(y: 8))
                    )
                )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(query.isEmpty ? "Keine weiteren Playlists gefunden." : "Keine Treffer für deine Suche.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(query.isEmpty ? "Du kannst in Spotify eine Playlist erstellen und danach hier aktualisieren." : "Passe den Suchbegriff an oder aktualisiere die Liste.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                    if query.isEmpty {
                        Button {
                            createPlaylistInSpotify()
                        } label: {
                            Label("Neue Playlist in Spotify anlegen", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(StyleKit.accent)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var playlistList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(query.isEmpty ? "Weitere Playlists" : "Suchergebnisse")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))

                    Spacer()

                    Text("\(selectablePlaylists.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        )
                }
                .padding(.horizontal, 2)
                .padding(.top, 2)

                LazyVStack(spacing: 10) {
                    ForEach(selectablePlaylists) { playlist in
                        Button {
                            Task {
                                isSwitchingPlaylist = true
                                defer { isSwitchingPlaylist = false }
                                await onSelect(playlist)
                                if allowsCollapse {
                                    withAnimation(detentAnimation) {
                                        detent = .height(Self.minimizedDetentHeight)
                                    }
                                } else {
                                    dismiss()
                                }
                            }
                        } label: {
                            playlistRow(playlist)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSwitchingPlaylist)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 96)
        }
        .refreshable {
            await onRefresh()
        }
    }

    // MARK: - Playlist Row
    private func playlistRow(_ playlist: SpotifyAPI.Playlist) -> some View {
        HStack(spacing: 12) {
            playlistArtwork(playlist, isCompact: false)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle = playlistSubtitle(playlist) {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
    }

    // MARK: - Artwork Helpers
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
            RoundedRectangle(cornerRadius: isCompact ? 12 : 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
            Image(systemName: "music.note")
                .font(.system(size: isCompact ? 14 : 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    // MARK: - Text Helpers
    private var compactDescription: String? {
        guard let currentSelected else {
            return playlists.isEmpty ? "Keine Playlist verfügbar" : "Tippe zum Auswählen"
        }
        return playlistSubtitle(currentSelected)
    }

    private func playlistSubtitle(_ playlist: SpotifyAPI.Playlist) -> String? {
        let trimmed = (playlist.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func toggleDetent() {
        guard allowsCollapse else { return }
        withAnimation(detentAnimation) {
            detent = isMinimized ? .medium : .height(Self.minimizedDetentHeight)
        }
    }

    private func createPlaylistInSpotify() {
        guard let url = URL(string: "https://open.spotify.com/collection/playlists") else { return }
        openURL(url)
    }
}


#Preview("PlaylistSheetView") {
    struct PreviewHost: View {
        @State private var selectedId: String? = nil
        @State private var detent: PresentationDetent = .height(PlaylistSheetView.minimizedDetentHeight)
        @State private var showSheet: Bool = true

        var samplePlaylists: [SpotifyAPI.Playlist] {
            [
                .init(
                    id: "1",
                    name: "Daily Mix",
                    description: "Handpicked for you",
                    images: [ .init(url: "https://via.placeholder.com/150", height: 150, width: 150) ],
                    owner: .init(id: "Preview Owner"),
                    collaborative: false
                ),
                .init(
                    id: "2",
                    name: "Top Hits",
                    description: "Hot right now",
                    images: [ .init(url: "https://via.placeholder.com/150", height: 150, width: 150) ],
                    owner: .init(id: "Preview Owner"),
                    collaborative: false
                ),
                .init(
                    id: "3",
                    name: "Chill Vibes",
                    description: "Relax and unwind",
                    images: [ .init(url: "https://via.placeholder.com/150", height: 150, width: 150) ],
                    owner: .init(id: "Preview Owner"),
                    collaborative: false
                )
            ]
        }

        var body: some View {
            ZStack {
                AppBackground()
                Text("Host View")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .sheet(isPresented: $showSheet) {
                PlaylistSheetView(
                    playlists: samplePlaylists,
                    selectedId: $selectedId,
                    selectedPlaylist: samplePlaylists.first,
                    isRefreshing: false,
                    isLoadingPlaylists: false,
                    detent: $detent,
                    onSelect: { _ in },
                    onRefresh: {}
                )
                .presentationDetents([.height(PlaylistSheetView.minimizedDetentHeight), .medium], selection: $detent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
            .onAppear { showSheet = true }
        }
    }
    return PreviewHost()
}
