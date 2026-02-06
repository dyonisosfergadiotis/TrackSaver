import Foundation

enum SpotifyConfig {
    // TODO: Set this to your Spotify App Client ID (Spotify Developer Dashboard)
    static let clientId = "715940525eac4f2a8abeb044853a651e"

    // TODO: Must be registered in Spotify Dashboard AND in Xcode URL Types.
    // Example: "tracksaver://auth"
    static let redirectURI = "tracksaver://callback"

    static let scopes = [
        "user-read-currently-playing",
        "user-read-playback-state",
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-private",
        "playlist-modify-public"
    ]
}
