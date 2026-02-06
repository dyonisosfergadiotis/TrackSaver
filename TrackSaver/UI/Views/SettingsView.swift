import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("LocalHistoryJSON") private var historyJSON: String = ""
    @AppStorage("DefaultPlaylistId", store: SharedDefaults.store) private var defaultPlaylistId: String = ""
    @AppStorage("AccountUserId") private var accountUserId: String = ""
    @AppStorage("AccountDisplayName") private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL") private var accountAvatarURL: String = ""

    @State private var isLoading = true
    @State private var userId: String = "—"
    @State private var displayName: String = "—"
    @State private var defaultPlaylistName: String = "—"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        header

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Account")
                                if isLoading {
                                    HStack {
                                        ProgressView()
                                        Text("Lade Account…")
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                } else {
                                    if !accountAvatarURL.isEmpty {
                                        avatarRow
                                    }
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionTitle(title: "Aktionen")
                                Button(role: .destructive) {
                                    KeychainStore().deleteAllTokens()
                                    spotifyLoggedIn = false
                                    dismiss()
                                } label: {
                                    actionRow(title: "Abmelden", systemImage: "person.crop.circle.badge.xmark")
                                }
                                Button(role: .destructive) {
                                    historyJSON = ""
                                } label: {
                                    actionRow(title: "Historie löschen", systemImage: "trash")
                                }
                            }
                        }

                        if let errorMessage {
                            GlassCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text(errorMessage)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionTitle(title: "Info")
                                infoRow(
                                    title: "Version",
                                    value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                                )
                            }
                        }
                    }
                    .padding(20)
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
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Account, Historie und App-Info")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                IconBadge(systemName: "xmark")
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func actionRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StyleKit.accent)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .foregroundStyle(.white)
    }

    private var avatarRow: some View {
        HStack(spacing: 12) {
            RemoteImage(url: URL(string: accountAvatarURL)!) { avatarFallback }
                .scaledToFill()
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    
                Text(userId)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.white.opacity(0.7))
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
            let playlists = try await SpotifyAPI.shared.fetchPlaylists()
            if !defaultPlaylistId.isEmpty,
               let match = playlists.first(where: { $0.id == defaultPlaylistId }) {
                defaultPlaylistName = match.name
            } else {
                defaultPlaylistName = "—"
            }
            errorMessage = nil
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
