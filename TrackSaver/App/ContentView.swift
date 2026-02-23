import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedWalkthrough") private var hasCompletedWalkthrough = false
    @AppStorage("SpotifyLoggedIn") private var spotifyLoggedIn = false
    @AppStorage("AccountUserId") private var accountUserId: String = ""
    @AppStorage("AccountDisplayName") private var accountDisplayName: String = ""
    @AppStorage("AccountAvatarURL") private var accountAvatarURL: String = ""

    @State private var isCheckingToken = true

    var body: some View {
        Group {
            if !hasCompletedWalkthrough {
                WalkthroughView(
                    isComplete: $hasCompletedWalkthrough,
                    isReturningUser: false
                )
            } else if isCheckingToken {
                ProgressView("Prüfe Anmeldung…")
            } else if spotifyLoggedIn {
                MainView()
            } else {
                WalkthroughView(
                    isComplete: $hasCompletedWalkthrough,
                    isReturningUser: true
                )
            }
        }
        .task { await checkSessionOnLaunch() }
    }

    private func checkSessionOnLaunch() async {
        defer { isCheckingToken = false }
        do {
            let me = try await SpotifyAPI.shared.fetchMe()
            accountUserId = me.id
            accountDisplayName = me.display_name ?? ""
            accountAvatarURL = me.images?.first?.url ?? ""
            spotifyLoggedIn = true
        } catch {
            spotifyLoggedIn = false
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
