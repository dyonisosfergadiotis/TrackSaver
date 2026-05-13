import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedWalkthrough") private var hasCompletedWalkthrough = false
    @AppStorage("SpotifyLoggedIn", store: SharedDefaults.store) private var spotifyLoggedIn = false

    @State private var isCheckingToken = true

    var body: some View {
        Group {
            if isCheckingToken {
                ProgressView("Prüfe Anmeldung…")
            } else if spotifyLoggedIn {
                MainView()
            } else if !hasCompletedWalkthrough {
                WalkthroughView(
                    isComplete: $hasCompletedWalkthrough,
                    isReturningUser: false
                )
            } else {
                WalkthroughView(
                    isComplete: $hasCompletedWalkthrough,
                    isReturningUser: true
                )
            }
        }
        .task { await checkSessionOnLaunch() }
        .task { await NotificationHelper.requestAuthorizationFromActiveApp() }
    }

    private func checkSessionOnLaunch() async {
        SharedDefaults.migrateDefaultPlaylistIdIfNeeded()
        SharedDefaults.migrateLegacyAccountIfNeeded()
        CloudAccountSyncService.shared.refreshFromCloud()
        defer { isCheckingToken = false }

        let keychain = KeychainStore()
        let hasTokens = keychain.hasAuthTokens()
        guard spotifyLoggedIn || hasTokens else { return }

        if spotifyLoggedIn && !hasTokens {
            await waitForSyncedTokens()
            guard keychain.hasAuthTokens() else { return }
        }

        do {
            let me = try await SpotifyAPI.shared.fetchMe()
            CloudAccountSyncService.shared.updateLoggedInAccount(
                userId: me.id,
                displayName: me.display_name ?? "",
                avatarURL: me.images?.first?.url ?? ""
            )
            hasCompletedWalkthrough = true
        } catch {
            if let apiError = error as? SpotifyAPIError, case .unauthorized = apiError {
                CloudAccountSyncService.shared.logout()
            }
        }
    }

    private func waitForSyncedTokens() async {
        let keychain = KeychainStore()
        for _ in 0..<12 {
            if keychain.hasAuthTokens() {
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}
