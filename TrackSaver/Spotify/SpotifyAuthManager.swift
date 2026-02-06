import Foundation
import AuthenticationServices
import UIKit

final class SpotifyAuthManager: NSObject {
    private let keychain = KeychainStore()
    private var authSession: ASWebAuthenticationSession?

    func login() async throws {
        let verifier = OAuthPKCE.generateVerifier()
        let challenge = OAuthPKCE.codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes.joined(separator: " "))
        ]

        let callbackScheme = URL(string: SpotifyConfig.redirectURI)?.scheme
        guard let authURL = components.url, let callbackScheme else {
            throw SpotifyAuthError.invalidConfig
        }

        let callbackURL = try await startWebAuthSession(url: authURL, callbackScheme: callbackScheme)
        guard let code = extractQueryItem("code", from: callbackURL) else {
            throw SpotifyAuthError.missingAuthCode
        }

        let tokenResponse = try await requestToken(
            params: [
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": SpotifyConfig.redirectURI,
                "client_id": SpotifyConfig.clientId,
                "code_verifier": verifier
            ]
        )
        persistTokenResponse(tokenResponse)
    }

    func refreshIfNeeded() async throws -> String {
        if let access = keychain.readAccessToken(),
           let exp = keychain.readAccessTokenExpiration(),
           exp.timeIntervalSinceNow > 60 {
            return access
        }

        guard let refresh = keychain.readRefreshToken() else {
            throw SpotifyAuthError.missingRefreshToken
        }

        let tokenResponse = try await requestToken(
            params: [
                "grant_type": "refresh_token",
                "refresh_token": refresh,
                "client_id": SpotifyConfig.clientId
            ]
        )
        persistTokenResponse(tokenResponse, fallbackRefreshToken: refresh)
        guard let access = keychain.readAccessToken() else {
            throw SpotifyAuthError.missingAccessToken
        }
        return access
    }

    func logout() {
        keychain.deleteAllTokens()
    }

    // MARK: - Token Handling

    private struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
        let scope: String?
    }

    private func persistTokenResponse(_ response: TokenResponse, fallbackRefreshToken: String? = nil) {
        keychain.saveAccessToken(response.access_token)
        let refresh = response.refresh_token ?? fallbackRefreshToken
        if let refresh {
            keychain.saveRefreshToken(refresh)
        }
        let exp = Date().addingTimeInterval(TimeInterval(response.expires_in))
        keychain.saveAccessTokenExpiration(exp)
    }

    private func requestToken(params: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(params)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyAuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SpotifyAuthError.httpStatus(http.statusCode)
        }
        do { return try JSONDecoder().decode(TokenResponse.self, from: data) }
        catch { throw SpotifyAuthError.decodingFailed(error) }
    }

    private func formBody(_ params: [String: String]) -> Data? {
        let encoded = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        return encoded.data(using: .utf8)
    }

    // MARK: - Web Auth

    @MainActor
    private func startWebAuthSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SpotifyAuthError.missingCallbackURL)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            if authSession?.start() != true {
                continuation.resume(throwing: SpotifyAuthError.sessionFailed)
            }
        }
    }

    private func extractQueryItem(_ name: String, from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

enum SpotifyAuthError: LocalizedError {
    case invalidConfig
    case missingAuthCode
    case missingCallbackURL
    case missingRefreshToken
    case missingAccessToken
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)
    case sessionFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "Spotify-Konfiguration ist ungültig."
        case .missingAuthCode:
            return "Authorization Code fehlt."
        case .missingCallbackURL:
            return "Callback URL fehlt."
        case .missingRefreshToken:
            return "Refresh Token fehlt."
        case .missingAccessToken:
            return "Access Token fehlt."
        case .invalidResponse:
            return "Ungültige Spotify-Antwort."
        case .httpStatus(let code):
            return "Spotify antwortete mit Statuscode \(code)."
        case .decodingFailed(let error):
            return "Decoding fehlgeschlagen: \(error.localizedDescription)"
        case .sessionFailed:
            return "Login-Session konnte nicht gestartet werden."
        }
    }
}
