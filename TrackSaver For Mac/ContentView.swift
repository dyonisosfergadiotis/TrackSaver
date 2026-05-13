import SwiftUI

enum TrackSaverForMacLaunchState: Equatable {
    case checking
    case needsIOSLaunch
    case needsSpotifyConnection
    case needsPlaylistSelection
    case ready
}

enum TrackSaverForMacLayout {
    static let popoverWidth: CGFloat = 320
    static let expandedPopoverHeight: CGFloat = 412
    static let statusPopoverHeight: CGFloat = 249
    static let loadingPopoverHeight: CGFloat = 120

    static func popoverSize(for state: TrackSaverForMacLaunchState) -> CGSize {
        let height: CGFloat = switch state {
        case .checking:
            loadingPopoverHeight
        case .needsIOSLaunch, .needsSpotifyConnection, .needsPlaylistSelection:
            statusPopoverHeight
        case .ready:
            expandedPopoverHeight
        }

        return CGSize(width: popoverWidth, height: height)
    }
}

struct ContentView: View {
    @AppStorage("SpotifyLoggedIn", store: SharedDefaults.store) private var spotifyLoggedIn = false
    @AppStorage("DefaultPlaylistId", store: SharedDefaults.store) private var defaultPlaylistId = ""
    @AppStorage("IOSAppLaunched", store: SharedDefaults.store) private var iosAppLaunched = false
    @AppStorage("IOSLaunchRequestedByMac", store: SharedDefaults.store) private var iosLaunchRequestedByMac = false

    @State private var launchState: TrackSaverForMacLaunchState = .checking
    @State private var isRefreshingState = false
    private let onPreferredSizeChange: ((CGSize) -> Void)?

    init(onPreferredSizeChange: ((CGSize) -> Void)? = nil) {
        self.onPreferredSizeChange = onPreferredSizeChange
    }

    var body: some View {
        ZStack {
            switch launchState {
            case .checking:
                loadingView
            case .needsIOSLaunch:
                syncStatusView(
                    symbol: "iphone",
                    title: "TrackSaver auf dem iPhone starten",
                    message: iosLaunchRequestedByMac
                        ? "Der Mac wartet auf die erste iOS-Initialisierung. Dieser Zustand wurde in iCloud gespeichert und aktualisiert sich automatisch, sobald du die iPhone-App startest."
                        : "Öffne TrackSaver einmal auf deinem iPhone, damit Account und Ziel-Playlist per iCloud auf den Mac synchronisiert werden."
                )
            case .needsSpotifyConnection:
                syncStatusView(
                    symbol: "person.crop.circle.badge.exclamationmark",
                    title: "Spotify auf dem iPhone verbinden",
                    message: "Die Mac-App verwendet den iCloud-Status aus iOS. Öffne TrackSaver auf deinem iPhone und stelle sicher, dass Spotify dort angemeldet ist."
                )
            case .needsPlaylistSelection:
                syncStatusView(
                    symbol: "music.note.list",
                    title: "Playlist auf dem iPhone auswählen",
                    message: "Die Ziel-Playlist wird nur in der iPhone-App festgelegt. Öffne TrackSaver auf iOS und wähle dort die Playlist aus."
                )
            case .ready:
                MainView(presentation: .menuBarPopover)
            }
        }
        .frame(
            width: preferredSize.width,
            height: preferredSize.height
        )
        .tint(StyleKit.accent)
        .onAppear { reportPreferredSize() }
        .onChange(of: launchState) { _, _ in
            reportPreferredSize()
        }
        .task { await refreshLaunchState() }
        .onChange(of: spotifyLoggedIn) { _, _ in
            Task { await refreshLaunchState() }
        }
        .onChange(of: defaultPlaylistId) { _, _ in
            Task { await refreshLaunchState() }
        }
        .onChange(of: iosAppLaunched) { _, _ in
            Task { await refreshLaunchState() }
        }
    }

    private var preferredSize: CGSize {
        TrackSaverForMacLayout.popoverSize(for: launchState)
    }

    private func reportPreferredSize() {
        onPreferredSizeChange?(preferredSize)
    }

    private var loadingView: some View {
        ZStack {
            AppBackground(style: .menuBarPopover)
            GlassCard(style: .compact) {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Prüfe iCloud-Sync…")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(StyleKit.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func syncStatusView(symbol: String, title: String, message: String) -> some View {
        ZStack {
            AppBackground(style: .menuBarPopover)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    GlassCard(style: .compact) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(StyleKit.surfaceStrong)
                                    Image(systemName: symbol)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(StyleKit.accent)
                                }
                                .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(title)
                                        .font(.system(size: 19, weight: .bold, design: .rounded))
                                        .foregroundStyle(StyleKit.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(message)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(StyleKit.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Task { await refreshLaunchState(forceRequestIOSLaunch: false) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                            Text("Erneut prüfen")
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
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @MainActor
    private func refreshLaunchState(forceRequestIOSLaunch: Bool = true) async {
        guard !isRefreshingState else { return }
        isRefreshingState = true
        launchState = .checking
        defer { isRefreshingState = false }

        KeychainStore().migrateLegacyTokensIfNeeded(authenticationUI: .fail)
        CloudAccountSyncService.shared.refreshFromCloud()

        let bootstrapSnapshot = SharedDefaults.loadIOSBootstrapSnapshot()
        guard bootstrapSnapshot.iosAppLaunched else {
            if forceRequestIOSLaunch {
                CloudAccountSyncService.shared.requestIOSLaunchFromMac()
            }
            launchState = .needsIOSLaunch
            return
        }

        guard SharedDefaults.isSpotifyLoggedIn() else {
            launchState = .needsSpotifyConnection
            return
        }

        let playlistId = SharedDefaults.defaultPlaylistId().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !playlistId.isEmpty else {
            launchState = .needsPlaylistSelection
            return
        }

        let keychain = KeychainStore()
        if !keychain.hasAuthTokens(authenticationUI: .fail) {
            await waitForSyncedTokens()
        }

        launchState = keychain.hasAuthTokens(authenticationUI: .fail) ? .ready : .needsSpotifyConnection
    }

    private func waitForSyncedTokens() async {
        let keychain = KeychainStore()
        for _ in 0..<12 {
            if keychain.hasAuthTokens(authenticationUI: .fail) {
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
