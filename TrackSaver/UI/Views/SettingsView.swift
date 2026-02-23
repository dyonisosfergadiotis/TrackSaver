import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("AccountUserId") private var accountUserId: String = ""
    @AppStorage("AccountDisplayName") private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL") private var accountAvatarURL: String = ""
    @AppStorage("DefaultPlaylistId", store: SharedDefaults.store) private var defaultPlaylistId: String = ""

    @State private var isLoading = true
    @State private var userId: String = "—"
    @State private var displayName: String = "—"
    @State private var errorMessage: String?
    @State private var didClearHistory = false
    @State private var editablePlaylists: [SpotifyAPI.Playlist] = []
    @State private var shortcutPlaylistSelections: [Int: String]

    init() {
        _shortcutPlaylistSelections = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: SharedDefaults.shortcutSlots.map {
                    ($0, SharedDefaults.configuredShortcutPlaylistId(for: $0))
                }
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        accountCard
                        shortcutCard
                        actionsCard

                        if didClearHistory {
                            GlassCard(style: .compact) {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(StyleKit.accent)
                                    Text("Historie wurde gelöscht.")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(StyleKit.textSecondary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let errorMessage {
                            GlassCard(style: .compact) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(StyleKit.accentWarm)
                                    Text(errorMessage)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(StyleKit.textSecondary)
                                }
                            }
                        }

                        infoCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .task { await loadAccountInfo() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Einstellungen")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(StyleKit.textPrimary)
                Text("Account, Shortcuts, Historie und App-Info")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                IconBadge(systemName: "xmark")
            }
        }
    }

    private var accountCard: some View {
        GlassCard(style: .hero) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionTitle(title: "Account")
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }

                HStack(spacing: 14) {
                    avatarView
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(StyleKit.textPrimary)
                            .lineLimit(1)

                        Text(userId)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(StyleKit.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }

                Text("Der Spotify-Account bleibt lokal gespeichert, bis du dich abmeldest.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
            }
        }
    }

    private var shortcutCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Schicht-Shortcuts")

                Text("Lege für Schicht 1 bis 3 je eine Playlist fest. Ohne Auswahl wird die Standard-Playlist verwendet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)

                ForEach(SharedDefaults.shortcutSlots, id: \.self) { slot in
                    Menu {
                        Button {
                            setShortcutPlaylist("", for: slot)
                        } label: {
                            if shortcutSelection(for: slot).isEmpty {
                                Label("Standard-Playlist", systemImage: "checkmark")
                            } else {
                                Text("Standard-Playlist")
                            }
                        }

                        if !editablePlaylists.isEmpty {
                            ForEach(editablePlaylists) { playlist in
                                Button {
                                    setShortcutPlaylist(playlist.id, for: slot)
                                } label: {
                                    if shortcutSelection(for: slot) == playlist.id {
                                        Label(playlist.name, systemImage: "checkmark")
                                    } else {
                                        Text(playlist.name)
                                    }
                                }
                            }
                        }
                    } label: {
                        actionRow(
                            title: "Schicht \(slot)",
                            subtitle: shortcutSubtitle(for: slot),
                            systemImage: "\(slot).circle.fill",
                            tint: StyleKit.accent
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || (editablePlaylists.isEmpty && defaultPlaylistId.isEmpty))
                }

                Text("Segment-Logik: Schicht 1 (06-14 Uhr), Schicht 2 (14-22 Uhr), Schicht 3 (22-06 Uhr).")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textMuted)
            }
        }
    }

    private var actionsCard: some View {
        GlassCard(style: .standard) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Aktionen")

                Button(role: .destructive) {
                    KeychainStore().deleteAllTokens()
                    spotifyLoggedIn = false
                    dismiss()
                } label: {
                    actionRow(
                        title: "Abmelden",
                        subtitle: "Spotify-Verbindung auf diesem Gerät entfernen",
                        systemImage: "person.crop.circle.badge.xmark",
                        tint: StyleKit.accentWarm
                    )
                }

                Button(role: .destructive) {
                    guard !accountUserId.isEmpty else { return }
                    SharedDefaults.clearHistory(for: accountUserId)
                    withAnimation(.easeInOut(duration: 0.22)) {
                        didClearHistory = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2.2))
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                didClearHistory = false
                            }
                        }
                    }
                } label: {
                    actionRow(
                        title: "Historie löschen",
                        subtitle: "Alle lokal gespeicherten Einträge entfernen",
                        systemImage: "trash",
                        tint: StyleKit.accentWarm
                    )
                }
            }
        }
    }

    private var infoCard: some View {
        GlassCard(style: .compact) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Info")
                infoRow(
                    title: "Version",
                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                )
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(StyleKit.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(StyleKit.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func actionRow(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StyleKit.surfaceSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(StyleKit.strokeSoft, lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(StyleKit.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(StyleKit.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(StyleKit.surfaceSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(StyleKit.strokeSoft, lineWidth: 1)
                )
                .glassEffect(
                    StyleKit.glass(tint: tint.opacity(0.10), interactive: true),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = URL(string: accountAvatarURL), !accountAvatarURL.isEmpty {
            RemoteImage(url: url) { avatarFallback }
                .scaledToFill()
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StyleKit.surfaceStrong)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(StyleKit.textMuted)
        }
    }

    private func shortcutSelection(for slot: Int) -> String {
        shortcutPlaylistSelections[slot] ?? ""
    }

    private func setShortcutPlaylist(_ playlistId: String, for slot: Int) {
        shortcutPlaylistSelections[slot] = playlistId
        SharedDefaults.setShortcutPlaylistId(playlistId, for: slot)
    }

    private func shortcutSubtitle(for slot: Int) -> String {
        let configured = shortcutSelection(for: slot)
        if !configured.isEmpty {
            return playlistName(for: configured) ?? "Playlist-ID: \(configured.prefix(8))…"
        }

        if defaultPlaylistId.isEmpty {
            return "Standard-Playlist nicht gesetzt"
        }
        if let defaultName = playlistName(for: defaultPlaylistId) {
            return "Standard: \(defaultName)"
        }
        return "Standard-Playlist"
    }

    private func playlistName(for playlistId: String) -> String? {
        guard !playlistId.isEmpty else { return nil }
        return editablePlaylists.first(where: { $0.id == playlistId })?.name
    }

    private func filterEditablePlaylists(_ input: [SpotifyAPI.Playlist], userId: String) -> [SpotifyAPI.Playlist] {
        input.filter { playlist in
            if playlist.owner.id == userId { return true }
            if playlist.collaborative == true { return true }
            return false
        }
    }

    private func loadAccountInfo() async {
        isLoading = true
        defer { isLoading = false }

        if !accountDisplayName.isEmpty || !accountUserId.isEmpty {
            displayName = accountDisplayName.isEmpty ? "—" : accountDisplayName
            userId = accountUserId.isEmpty ? "—" : accountUserId
        }

        do {
            let me = try await SpotifyAPI.shared.fetchMe()
            accountUserId = me.id
            accountDisplayName = me.display_name ?? ""
            accountAvatarURL = me.images?.first?.url ?? ""
            displayName = accountDisplayName.isEmpty ? "—" : accountDisplayName
            userId = accountUserId.isEmpty ? "—" : accountUserId

            do {
                let playlistsResponse = try await SpotifyAPI.shared.fetchPlaylists()
                editablePlaylists = filterEditablePlaylists(playlistsResponse, userId: me.id)
                errorMessage = nil
            } catch {
                if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                    KeychainStore().deleteAllTokens()
                    spotifyLoggedIn = false
                    dismiss()
                    return
                }
                editablePlaylists = []
                errorMessage = "Playlists konnten nicht geladen werden: \(error.localizedDescription)"
            }
        } catch {
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                KeychainStore().deleteAllTokens()
                spotifyLoggedIn = false
                dismiss()
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
