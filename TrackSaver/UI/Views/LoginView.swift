import SwiftUI

struct LoginView: View {
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("AccountUserId") private var accountUserId: String = ""
    @AppStorage("AccountDisplayName") private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL") private var accountAvatarURL: String = ""

    @State private var isLoggingIn = false
    @State private var statusMessage: String?
    private let auth = SpotifyAuthManager()

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 10) {
                            Text("Willkommen zurück")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Melde dich an, um Tracks direkt in deine Playlist zu speichern.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        GlassCard {
                            VStack(spacing: 14) {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Einmal anmelden, danach bleibt’s gespeichert.")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }

                                Button {
                                    Task { await loginWithSpotify() }
                                } label: {
                                    HStack(spacing: 10) {
                                        if isLoggingIn { ProgressView() }
                                        Text(isLoggingIn ? "Anmelden…" : "Mit Spotify anmelden")
                                    }
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .disabled(isLoggingIn)
                                .buttonStyle(.borderedProminent)
                                .tint(StyleKit.accent)
                                .foregroundStyle(.black)
                            }
                        }

                        if let message = statusMessage, !message.isEmpty {
                            GlassCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text(message)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func loginWithSpotify() async {
        if SpotifyConfig.clientId == "YOUR_SPOTIFY_CLIENT_ID" {
            statusMessage = "Bitte Spotify Client ID und Redirect URI in SpotifyConfig.swift setzen."
            return
        }

        statusMessage = nil
        isLoggingIn = true
        defer { isLoggingIn = false }

        do {
            try await auth.login()
            let me = try await SpotifyAPI.shared.fetchMe()
            accountUserId = me.id
            accountDisplayName = me.display_name ?? ""
            accountAvatarURL = me.images?.first?.url ?? ""
            statusMessage = "Login erfolgreich."
            spotifyLoggedIn = true
        } catch {
            KeychainStore().deleteAllTokens()
            statusMessage = error.localizedDescription
            spotifyLoggedIn = false
        }
    }
}
