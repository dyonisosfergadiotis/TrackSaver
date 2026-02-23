import SwiftUI

struct WalkthroughView: View {
    @Binding var isComplete: Bool
    let isReturningUser: Bool
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("AccountUserId") private var accountUserId: String = ""
    @AppStorage("AccountDisplayName") private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL") private var accountAvatarURL: String = ""

    @State private var isLoggingIn = false
    @State private var statusMessage: String?
    private let auth = SpotifyAuthManager()

    private let highlights: [WalkthroughFeature] = [
        .init(
            symbol: "play.circle.fill",
            title: "Aktuellen Song speichern",
            detail: "Nimmt den gerade laufenden Track direkt."
        ),
        .init(
            symbol: "music.note.list",
            title: "Playlist gezielt wählen",
            detail: "Du entscheidest, wohin gespeichert wird."
        ),
        .init(
            symbol: "clock.arrow.circlepath",
            title: "Historie lokal behalten",
            detail: "Siehst, was du zuletzt gespeichert hast."
        )
    ]

    init(isComplete: Binding<Bool>, isReturningUser: Bool = false) {
        self._isComplete = isComplete
        self.isReturningUser = isReturningUser
    }

    private var headerTitle: String {
        isReturningUser ? "Willkommen zurück" : "Willkommen zu TrackSaver"
    }

    private var headerSubtitle: String {
        isReturningUser
            ? "Melde dich wieder mit Spotify an und speichere sofort weiter."
            : "Speichere laufende Songs in Sekunden in deine Playlist."
    }

    private var buttonTitle: String {
        isReturningUser ? "Mit Spotify anmelden" : "Mit Spotify starten"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(headerTitle)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(headerSubtitle)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(StyleKit.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 26)

                        VStack(spacing: 18) {
                            ForEach(Array(highlights.enumerated()), id: \.element.id) { index, feature in
                                WalkthroughFeatureRow(feature: feature)
                                if index < highlights.count - 1 {
                                    Divider()
                                        .overlay(StyleKit.strokeSoft)
                                        .padding(.leading, 42)
                                }
                            }
                        }

                        if let statusMessage, !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(StyleKit.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 126)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Button {
                        Task { await loginWithSpotify() }
                    } label: {
                        HStack(spacing: 10) {
                            if isLoggingIn {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            Text(isLoggingIn ? "Anmelden…" : buttonTitle)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .disabled(isLoggingIn)
                    .buttonStyle(.borderedProminent)
                    .tint(StyleKit.accent)
                    .foregroundStyle(.black)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    Color.black.opacity(0.12)
                        .blur(radius: 12)
                    .ignoresSafeArea(edges: .bottom)
                )
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
            spotifyLoggedIn = true
            isComplete = true
        } catch {
            KeychainStore().deleteAllTokens()
            statusMessage = error.localizedDescription
            spotifyLoggedIn = false
        }
    }
}

private struct WalkthroughFeature: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String

    init(symbol: String, title: String, detail: String) {
        self.id = title
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }
}

private struct WalkthroughFeatureRow: View {
    let feature: WalkthroughFeature

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(feature.detail)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
