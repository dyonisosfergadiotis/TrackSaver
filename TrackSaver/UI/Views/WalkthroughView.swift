import SwiftUI

struct WalkthroughView: View {
    @Binding var isComplete: Bool
    let isReturningUser: Bool
    let presentation: TrackSaverPresentationStyle

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
            title: "Historie via iCloud behalten",
            detail: "Login und Verlauf bleiben auf deinen Geräten synchron."
        )
    ]

    init(
        isComplete: Binding<Bool>,
        isReturningUser: Bool = false,
        presentation: TrackSaverPresentationStyle = .standard
    ) {
        self._isComplete = isComplete
        self.isReturningUser = isReturningUser
        self.presentation = presentation
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
        Group {
            if presentation == .menuBarPopover {
                popoverBody
            } else {
                standardBody
            }
        }
    }

    private var standardBody: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(headerTitle)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(StyleKit.textPrimary)
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

                        GlassCard(style: .hero) {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(StyleKit.accent)
                                    Text("Schneller Zugriff")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .tracking(0.8)
                                        .foregroundStyle(StyleKit.textMuted)
                                }

                                ForEach(Array(highlights.enumerated()), id: \.element.id) { index, feature in
                                    WalkthroughFeatureRow(feature: feature)
                                    if index < highlights.count - 1 {
                                        Divider()
                                            .overlay(StyleKit.strokeSoft)
                                            .padding(.leading, 42)
                                    }
                                }
                            }
                        }

                        if let statusMessage, !statusMessage.isEmpty {
                            GlassCard(style: .compact) {
                                Text(statusMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(StyleKit.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                                    .tint(StyleKit.textPrimary)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            Text(isLoggingIn ? "Anmelden…" : buttonTitle)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LiquidGlassPlate(
                                cornerRadius: 18,
                                tint: StyleKit.accent.opacity(0.78),
                                edgeTint: Color.white.opacity(0.26),
                                glowColor: StyleKit.glassGlowWarm,
                                material: .regularMaterial,
                                shadowOpacity: 0.24,
                                shadowRadius: 12,
                                shadowY: 5
                            )
                        )
                    }
                    .disabled(isLoggingIn)
                    .opacity(isLoggingIn ? 0.84 : 1)
                    .foregroundStyle(StyleKit.textPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [
                                    StyleKit.glassSpecular.opacity(0.34),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 24)
                        }
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            #endif
        }
    }

    private var popoverBody: some View {
        ZStack {
            AppBackground(style: .menuBarPopover)

            VStack(alignment: .leading, spacing: 16) {
                GlassCard(style: .compact) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(StyleKit.surfaceStrong)
                            Image(systemName: "music.note.list")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(StyleKit.accent)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(headerTitle)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(StyleKit.textPrimary)
                            Text(headerSubtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(StyleKit.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                GlassCard(style: .compact) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Funktionen")
                        ForEach(Array(highlights.enumerated()), id: \.element.id) { index, feature in
                            WalkthroughFeatureRow(feature: feature, compact: true)
                            if index < highlights.count - 1 {
                                Divider()
                                    .overlay(StyleKit.strokeSoft)
                                    .padding(.leading, 38)
                            }
                        }
                    }
                }

                if let statusMessage, !statusMessage.isEmpty {
                    GlassCard(style: .compact) {
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(StyleKit.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await loginWithSpotify() }
                } label: {
                    HStack(spacing: 10) {
                        if isLoggingIn {
                            ProgressView()
                                .controlSize(.small)
                                .tint(StyleKit.textPrimary)
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Text(isLoggingIn ? "Anmelden…" : buttonTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(StyleKit.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(StyleKit.accent.opacity(0.82))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoggingIn)
                .opacity(isLoggingIn ? 0.84 : 1)
            }
            .padding(16)
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
            CloudAccountSyncService.shared.updateLoggedInAccount(
                userId: me.id,
                displayName: me.display_name ?? "",
                avatarURL: me.images?.first?.url ?? ""
            )
            isComplete = true
        } catch {
            statusMessage = error.localizedDescription
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                CloudAccountSyncService.shared.logout()
            }
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
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.symbol)
                .font(.system(size: compact ? 15 : 18, weight: .semibold))
                .foregroundStyle(StyleKit.textPrimary)
                .frame(width: compact ? 26 : 30, height: compact ? 26 : 30, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: compact ? 14 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(StyleKit.textPrimary)
                Text(feature.detail)
                    .font(.system(size: compact ? 12 : 14, weight: .medium, design: .rounded))
                    .foregroundStyle(StyleKit.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
