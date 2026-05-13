import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class SpotifyAuthManager: NSObject {
    private let keychain = KeychainStore()
    private var authSession: ASWebAuthenticationSession?
    private let maxLoginAttempts = 2
    private let maxTokenRequestAttempts = 3
    #if os(macOS)
    // Trigger one immediate restart to emulate a popup reload before user interaction.
    private let macOSInitialAuthReloadDelayNanoseconds: UInt64 = 250_000_000
    #endif
    private static let formBodyAllowedCharacters: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._* ")
        return allowed
    }()

    func login() async throws {
        var lastError: Error?
        for attempt in 1...maxLoginAttempts {
            do {
                try await performLoginAttempt(preferEphemeralWebSession: attempt > 1)
                return
            } catch {
                lastError = error
                guard shouldRetryLogin(error: error, attempt: attempt) else {
                    throw error
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
        throw lastError ?? SpotifyAuthError.sessionFailed
    }

    private func performLoginAttempt(preferEphemeralWebSession: Bool) async throws {
        let verifier = OAuthPKCE.generateVerifier()
        let challenge = OAuthPKCE.codeChallenge(for: verifier)
        let state = OAuthPKCE.generateVerifier()

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]

        let callbackScheme = URL(string: SpotifyConfig.redirectURI)?.scheme
        guard let authURL = components.url, let callbackScheme else {
            throw SpotifyAuthError.invalidConfig
        }

        let callbackURL = try await startWebAuthSession(
            url: authURL,
            callbackScheme: callbackScheme,
            preferEphemeralWebSession: preferEphemeralWebSession
        )
        if let authError = extractQueryItem("error", from: callbackURL) {
            throw SpotifyAuthError.authorizationFailed(authError)
        }
        guard extractQueryItem("state", from: callbackURL) == state else {
            throw SpotifyAuthError.stateMismatch
        }
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
        CloudAccountSyncService.shared.logout()
    }

    // MARK: - Token Handling

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
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
        for attempt in 1...maxTokenRequestAttempts {
            do {
                return try await requestTokenOnce(params: params)
            } catch {
                guard shouldRetryTokenRequest(error: error, attempt: attempt) else {
                    throw error
                }
                try? await Task.sleep(for: .milliseconds(300 * attempt))
            }
        }
        throw SpotifyAuthError.sessionFailed
    }

    private func requestTokenOnce(params: [String: String]) async throws -> TokenResponse {
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
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(formURLEncode(key))=\(formURLEncode(value))"
            }
            .joined(separator: "&")
        return encoded.data(using: .utf8)
    }

    private func formURLEncode(_ value: String) -> String {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: Self.formBodyAllowedCharacters) ?? ""
        return encoded.replacingOccurrences(of: " ", with: "+")
    }

    // MARK: - Web Auth

    @MainActor
    private func startWebAuthSession(
        url: URL,
        callbackScheme: String,
        preferEphemeralWebSession: Bool
    ) async throws -> URL {
        #if os(macOS)
        if !preferEphemeralWebSession {
            return try await startWebAuthSessionWithInitialMacOSReload(
                url: url,
                callbackScheme: callbackScheme,
                preferEphemeralWebSession: preferEphemeralWebSession
            )
        }
        #endif

        return try await startSingleWebAuthSession(
            url: url,
            callbackScheme: callbackScheme,
            preferEphemeralWebSession: preferEphemeralWebSession
        )
    }

    @MainActor
    private func startSingleWebAuthSession(
        url: URL,
        callbackScheme: String,
        preferEphemeralWebSession: Bool
    ) async throws -> URL {
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
            authSession?.prefersEphemeralWebBrowserSession = preferEphemeralWebSession
            if authSession?.start() != true {
                continuation.resume(throwing: SpotifyAuthError.sessionFailed)
            }
        }
    }

    #if os(macOS)
    private enum WebAuthFlowControl: Error {
        case restartAfterInitialLoad
    }

    @MainActor
    private func startWebAuthSessionWithInitialMacOSReload(
        url: URL,
        callbackScheme: String,
        preferEphemeralWebSession: Bool
    ) async throws -> URL {
        do {
            return try await withThrowingTaskGroup(of: URL.self) { group in
                group.addTask { [self] in
                    try await startSingleWebAuthSession(
                        url: url,
                        callbackScheme: callbackScheme,
                        preferEphemeralWebSession: preferEphemeralWebSession
                    )
                }

                group.addTask { [self] in
                    try await Task.sleep(nanoseconds: macOSInitialAuthReloadDelayNanoseconds)
                    await MainActor.run { self.authSession?.cancel() }
                    throw WebAuthFlowControl.restartAfterInitialLoad
                }

                let result = try await group.next()
                group.cancelAll()
                guard let result else { throw SpotifyAuthError.sessionFailed }
                return result
            }
        } catch WebAuthFlowControl.restartAfterInitialLoad {
            return try await startSingleWebAuthSession(
                url: url,
                callbackScheme: callbackScheme,
                preferEphemeralWebSession: preferEphemeralWebSession
            )
        }
    }
    #endif

    private func extractQueryItem(_ name: String, from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private func shouldRetryLogin(error: Error, attempt: Int) -> Bool {
        guard attempt < maxLoginAttempts else { return false }

        if let authError = error as? SpotifyAuthError {
            switch authError {
            case .httpStatus(let code):
                return (500...599).contains(code) || code == 400
            case .authorizationFailed(let errorCode):
                return errorCode == "server_error" || errorCode == "temporarily_unavailable"
            default:
                return isRetryableTransportError(error)
            }
        }

        return isRetryableTransportError(error)
    }

    private func shouldRetryTokenRequest(error: Error, attempt: Int) -> Bool {
        guard attempt < maxTokenRequestAttempts else { return false }

        if let authError = error as? SpotifyAuthError,
           case .httpStatus(let code) = authError {
            return (500...599).contains(code)
        }

        return isRetryableTransportError(error)
    }

    private func isRetryableTransportError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let windowScene else {
            preconditionFailure("No UIWindowScene available for ASWebAuthenticationSession presentation")
        }

        if let window = windowScene.windows.first(where: \.isKeyWindow) ?? windowScene.windows.first {
            return window
        }

        return ASPresentationAnchor(windowScene: windowScene)
        #elseif canImport(AppKit)
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) ?? NSApp.windows.first {
            return window
        }
        return NSWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

enum SpotifyAuthError: LocalizedError {
    case invalidConfig
    case stateMismatch
    case missingAuthCode
    case missingCallbackURL
    case missingRefreshToken
    case missingAccessToken
    case authorizationFailed(String)
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)
    case sessionFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "Spotify-Konfiguration ist ungültig."
        case .stateMismatch:
            return "Spotify-Login konnte nicht verifiziert werden. Bitte erneut versuchen."
        case .missingAuthCode:
            return "Authorization Code fehlt."
        case .missingCallbackURL:
            return "Callback URL fehlt."
        case .missingRefreshToken:
            return "Refresh Token fehlt."
        case .missingAccessToken:
            return "Access Token fehlt."
        case .authorizationFailed(let errorCode):
            return "Spotify-Anmeldung fehlgeschlagen (\(errorCode))."
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
