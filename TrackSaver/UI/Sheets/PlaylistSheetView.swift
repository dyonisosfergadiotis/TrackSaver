import SwiftUI

struct PlaylistSheetView: View {
    // MARK: - Inputs
    let playlists: [SpotifyAPI.Playlist]
    @Binding var selectedId: String?
    let selectedPlaylist: SpotifyAPI.Playlist?
    let isSaving: Bool
    @Binding var detent: PresentationDetent
    var onSelect: @Sendable (_ playlist: SpotifyAPI.Playlist) async -> Void
    var onSave: () -> Void
    var onRefresh: @Sendable () async -> Void

    // Local search state
    @State private var query: String = ""

    // Convenience flags for UI states
    private var isMinimized: Bool {
        detent == .height(80)
    }

    private var currentSelected: SpotifyAPI.Playlist? {
        playlists.first(where: { $0.id == selectedId }) ?? selectedPlaylist
    }

    private var filtered: [SpotifyAPI.Playlist] {
        guard !query.isEmpty else { return playlists }
        return playlists.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppBackground()

                VStack(spacing: 0) {
                    // MARK: - Compact Header (always visible)
                    headerPill
                        .padding(.horizontal, isMinimized ? 0 : 16)
                        .padding(.top, isMinimized ? 0 : 12)
                        .zIndex(2)

                    // MARK: - Expanded List
                    if !isMinimized {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filtered) { pl in
                                    if pl.id != selectedId {
                                        Button {
                                            Task { await onSelect(pl) }
                                        } label: {
                                            playlistRow(pl)
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .padding(.bottom, 80)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer()
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isMinimized)
            .navigationTitle(isMinimized ? "" : "Playlist wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isMinimized ? .hidden : .visible, for: .navigationBar)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                // Refresh only in expanded mode
                if !isMinimized {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await onRefresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Maps-Style Header Pill
    private var headerPill: some View {
        let content = HStack(spacing: 12) {
            compactArtwork
                .frame(width: isMinimized ? 40 : 48, height: isMinimized ? 40 : 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 0) {
                Text(currentSelected?.name ?? "Playlist wählen")
                    .font(.system(size: isMinimized ? 16 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(compactDescription)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            SaveButton(isLoading: isSaving, enabled: currentSelected != nil) {
                onSave()
            }
            .frame(width: isMinimized ? 40 : 50, height: isMinimized ? 40 : 50)
            .clipShape(Circle())
        }

        if isMinimized {
            // Minimized: pill fills the entire sheet width.
            return AnyView(
                content
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .glassEffect()
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
            )
        } else {
            // Expanded: same rounded rectangle style as playlist rows.
            return AnyView(
                GlassCard { content }
                    .frame(maxWidth: .infinity)
            )
        }
    }

    // MARK: - Playlist Row
    private func playlistRow(_ pl: SpotifyAPI.Playlist) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                playlistArtwork(pl)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(pl.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text(playlistSubtitle(pl))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
            }
        }
    }

    // MARK: - Artwork Helpers
    @ViewBuilder
    private var compactArtwork: some View {
        if let urlString = currentSelected?.images?.first?.url, let url = URL(string: urlString) {
            RemoteImage(url: url) { artworkFallback }.scaledToFill()
        } else {
            artworkFallback
        }
    }

    private var artworkFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1))
            Image(systemName: "music.note").font(.system(size: isMinimized ? 14 : 18)).foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Text Helpers
    private var compactDescription: String {
        guard let currentSelected else { return "Wähle eine Playlist" }
        let trimmed = (currentSelected.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? " " : trimmed
    }

    @ViewBuilder
    private func playlistArtwork(_ playlist: SpotifyAPI.Playlist) -> some View {
        if let urlString = playlist.images?.first?.url, let url = URL(string: urlString) {
            RemoteImage(url: url) { artworkFallback }.scaledToFill()
        } else {
            artworkFallback
        }
    }

    private func playlistSubtitle(_ playlist: SpotifyAPI.Playlist) -> String {
        let trimmed = (playlist.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? " " : trimmed
    }
}


#Preview("PlaylistSheetView") {
    struct PreviewHost: View {
        @State private var selectedId: String? = nil
        @State private var detent: PresentationDetent = .height(80)
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
                    isSaving: false,
                    detent: $detent,
                    onSelect: { _ in },
                    onSave: {},
                    onRefresh: {}
                )
                .presentationDetents([.height(80), .medium], selection: $detent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
            .onAppear { showSheet = true }
        }
    }
    return PreviewHost()
}
