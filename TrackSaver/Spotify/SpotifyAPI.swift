import Foundation

public enum SpotifyAPIError: LocalizedError {
    case unauthorized
    case missingAccessToken
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)
    case noCurrentTrack
    case duplicateTrack(String, String, String?)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Nicht autorisiert (401). Bitte erneut anmelden."
        case .missingAccessToken:
            return "Access Token fehlt."
        case .invalidResponse:
            return "Ungültige Spotify-Antwort."
        case .httpStatus(let code):
            return "Spotify antwortete mit Statuscode \(code)."
        case .decodingFailed(let error):
            return "Decoding fehlgeschlagen: \(error.localizedDescription)"
        case .noCurrentTrack:
            return "Kein aktuell spielender Track gefunden."
        case .duplicateTrack:
            return "Track ist bereits in der Playlist."
        }
    }
}

public actor SpotifyAPI {
    public static let shared = SpotifyAPI()

    private let baseURL = URL(string: "https://api.spotify.com/v1")!
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - DTOs

    public struct MeResponse: Codable {
        public let id: String
        public let display_name: String?
        public let images: [Image]?
    }

    public struct Playlist: Codable, Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let description: String?
        public let images: [Image]?
        public let owner: Owner
        public let collaborative: Bool?
    }

    public struct Owner: Codable, Equatable, Sendable {
        public let id: String?
    }

    public struct Image: Codable, Equatable, Sendable {
        public let url: String
        public let height: Int?
        public let width: Int?
    }

    private struct PlaylistsResponse: Codable {
        let items: [Playlist]
        let next: String?
    }

    private struct CurrentlyPlayingResponse: Codable {
        let item: Track?
    }

    private struct Track: Codable {
        let id: String?
        let name: String?
        let uri: String?
        let artists: [Artist]?
        let album: Album?
    }

    private struct Artist: Codable {
        let name: String
    }

    private struct Album: Codable {
        let images: [Image]?
    }

    private struct AddTracksRequest: Codable {
        let uris: [String]
    }

    private struct PlaylistTracksResponse: Codable {
        let items: [PlaylistTrackItem]
        let next: String?
    }

    private struct PlaylistTrackItem: Codable {
        let track: Track?
    }

    public struct AddTrackResult: Codable {
        public let trackId: String
        public let trackName: String
        public let artistName: String
        public let artworkURL: String?
    }

    // MARK: - Public Endpoints

    public func fetchMe() async throws -> MeResponse {
        let (data, response) = try await performRequest(path: "/me", method: "GET")
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 { throw SpotifyAPIError.unauthorized }
            throw SpotifyAPIError.httpStatus(response.statusCode)
        }
        do { return try decoder.decode(MeResponse.self, from: data) }
        catch { throw SpotifyAPIError.decodingFailed(error) }
    }

    public func fetchPlaylists() async throws -> [Playlist] {
        var all: [Playlist] = []
        var nextURL: URL? = makeURL("/me/playlists", query: [URLQueryItem(name: "limit", value: "50")])
        while let url = nextURL {
            let (data, response) = try await performRequest(url: url, method: "GET")
            guard (200...299).contains(response.statusCode) else {
                if response.statusCode == 401 { throw SpotifyAPIError.unauthorized }
                throw SpotifyAPIError.httpStatus(response.statusCode)
            }
            do {
                let page = try decoder.decode(PlaylistsResponse.self, from: data)
                all.append(contentsOf: page.items)
                nextURL = page.next.flatMap(URL.init(string:))
            } catch {
                throw SpotifyAPIError.decodingFailed(error)
            }
        }
        return all
    }

    public func addCurrentTrack(playlistId: String) async throws -> AddTrackResult {
        let (data, response) = try await performRequest(path: "/me/player/currently-playing", method: "GET")
        if response.statusCode == 204 { throw SpotifyAPIError.noCurrentTrack }
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 { throw SpotifyAPIError.unauthorized }
            throw SpotifyAPIError.httpStatus(response.statusCode)
        }
        let current: CurrentlyPlayingResponse
        do { current = try decoder.decode(CurrentlyPlayingResponse.self, from: data) }
        catch { throw SpotifyAPIError.decodingFailed(error) }

        guard let track = current.item, let uri = track.uri else {
            throw SpotifyAPIError.noCurrentTrack
        }
        let trackId = track.id ?? ""
        let artistName = track.artists?.first?.name ?? "Unbekannter Artist"
        let artworkURL = track.album?.images?.first?.url
        if !trackId.isEmpty {
            let exists = try await playlistContainsTrack(playlistId: playlistId, trackId: trackId)
            if exists {
                throw SpotifyAPIError.duplicateTrack(
                    track.name ?? "Unbekannter Track",
                    artistName,
                    artworkURL
                )
            }
        }

        let addBody = try JSONEncoder().encode(AddTracksRequest(uris: [uri]))
        let (addData, addResponse) = try await performRequest(
            path: "/playlists/\(playlistId)/tracks",
            method: "POST",
            body: addBody
        )
        guard (200...299).contains(addResponse.statusCode) else {
            if addResponse.statusCode == 401 { throw SpotifyAPIError.unauthorized }
            throw SpotifyAPIError.httpStatus(addResponse.statusCode)
        }

        _ = addData
        return AddTrackResult(
            trackId: track.id ?? "unknown",
            trackName: track.name ?? "Unbekannter Track",
            artistName: artistName,
            artworkURL: artworkURL
        )
    }

    private func playlistContainsTrack(playlistId: String, trackId: String) async throws -> Bool {
        var nextURL: URL? = makeURL(
            "/playlists/\(playlistId)/tracks",
            query: [
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "fields", value: "items(track(id)),next")
            ]
        )
        while let url = nextURL {
            let (data, response) = try await performRequest(url: url, method: "GET")
            guard (200...299).contains(response.statusCode) else {
                if response.statusCode == 401 { throw SpotifyAPIError.unauthorized }
                throw SpotifyAPIError.httpStatus(response.statusCode)
            }
            let page: PlaylistTracksResponse
            do { page = try decoder.decode(PlaylistTracksResponse.self, from: data) }
            catch { throw SpotifyAPIError.decodingFailed(error) }
            if page.items.contains(where: { $0.track?.id == trackId }) {
                return true
            }
            nextURL = page.next.flatMap(URL.init(string:))
        }
        return false
    }

    // MARK: - Low-level

    private func performRequest(path: String, method: String, body: Data? = nil, query: [URLQueryItem]? = nil) async throws -> (Data, HTTPURLResponse) {
        let url = makeURL(path, query: query)
        return try await performRequest(url: url, method: method, body: body)
    }

    private func performRequest(url: URL, method: String, body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        let token = try await ensureAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAPIError.invalidResponse }
        if http.statusCode == 401 {
            await MainActor.run {
                KeychainStore().deleteAccessToken()
            }
        }
        return (data, http)
    }

    private func ensureAccessToken() async throws -> String {
        let cachedToken = await MainActor.run { () -> String? in
            let keychain = KeychainStore()
            guard let access = keychain.readAccessToken(),
                  let exp = keychain.readAccessTokenExpiration(),
                  exp.timeIntervalSinceNow > 60 else {
                return nil
            }
            return access
        }
        if let cachedToken {
            return cachedToken
        }

        let refreshToken = await MainActor.run { KeychainStore().readRefreshToken() }
        guard let refreshToken else {
            throw SpotifyAPIError.missingAccessToken
        }

        let tokenResponse = try await refreshAccessToken(refreshToken: refreshToken)
        let newRefresh = tokenResponse.refresh_token ?? refreshToken
        let exp = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        await MainActor.run {
            let keychain = KeychainStore()
            keychain.saveAccessToken(tokenResponse.access_token)
            keychain.saveRefreshToken(newRefresh)
            keychain.saveAccessTokenExpiration(exp)
        }
        return tokenResponse.access_token
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String?
    }

    private func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": await MainActor.run { SpotifyConfig.clientId }
        ]
        request.httpBody = formBody(params)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAPIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SpotifyAPIError.httpStatus(http.statusCode)
        }
        do { return try decoder.decode(TokenResponse.self, from: data) }
        catch { throw SpotifyAPIError.decodingFailed(error) }
    }

    private func formBody(_ params: [String: String]) -> Data? {
        let encoded = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        return encoded.data(using: .utf8)
    }

    private func makeURL(_ path: String, query: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let query { components.queryItems = query }
        return components.url!
    }
}
