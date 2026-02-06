import Foundation
import Security

public struct KeychainStore {
    private let service = "TrackSaverSpotify"
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"
    private let expirationAccount = "accessTokenExpiration"
    // Shared access group for app + extensions (falls vorhanden). Fällt bei fehlender Entitlement sauber zurück.
    private let accessGroup = "8W4U9DBYVS.group.dyonisosfergadiotis.tracksaver"

    public init() {}

    // MARK: - Public API

    public func readAccessToken() -> String? {
        readString(account: accessTokenAccount)
    }

    public func readRefreshToken() -> String? {
        readString(account: refreshTokenAccount)
    }

    public func readAccessTokenExpiration() -> Date? {
        guard let raw = readString(account: expirationAccount), let interval = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    public func saveAccessToken(_ token: String) {
        saveString(token, account: accessTokenAccount)
    }

    public func saveRefreshToken(_ token: String) {
        saveString(token, account: refreshTokenAccount)
    }

    public func saveAccessTokenExpiration(_ date: Date) {
        saveString(String(date.timeIntervalSince1970), account: expirationAccount)
    }

    public func deleteAllTokens() {
        delete(account: accessTokenAccount)
        delete(account: refreshTokenAccount)
        delete(account: expirationAccount)
    }

    public func deleteAccessToken() {
        delete(account: accessTokenAccount)
        delete(account: expirationAccount)
    }

    public func migrateLegacyTokensIfNeeded() {
        // If shared-group tokens already exist, no work needed.
        if readString(account: accessTokenAccount) != nil || readString(account: refreshTokenAccount) != nil {
            return
        }
        if let legacyAccess = readString(account: accessTokenAccount, includeAccessGroup: false) {
            saveString(legacyAccess, account: accessTokenAccount)
        }
        if let legacyRefresh = readString(account: refreshTokenAccount, includeAccessGroup: false) {
            saveString(legacyRefresh, account: refreshTokenAccount)
        }
        if let legacyExp = readString(account: expirationAccount, includeAccessGroup: false) {
            saveString(legacyExp, account: expirationAccount)
        }
    }

    // MARK: - Helpers

    private func readString(account: String) -> String? {
        readString(account: account, includeAccessGroup: true)
    }

    private func readString(account: String, includeAccessGroup: Bool) -> String? {
        func query(includeAccessGroup: Bool) -> [String: Any] {
            var q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            if includeAccessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
            return q
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(includeAccessGroup: includeAccessGroup) as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        func baseQuery(includeAccessGroup: Bool) -> [String: Any] {
            var q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            if includeAccessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
            return q
        }

        var addQuery = baseQuery(includeAccessGroup: true)
        addQuery[kSecValueData as String] = data
        var status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attrs: [String: Any] = [kSecValueData as String: data]
            status = SecItemUpdate(baseQuery(includeAccessGroup: true) as CFDictionary, attrs as CFDictionary)
        }

        if status == errSecMissingEntitlement || status == errSecNoSuchKeychain || status == errSecInteractionNotAllowed {
            addQuery = baseQuery(includeAccessGroup: false)
            addQuery[kSecValueData as String] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
            if status == errSecDuplicateItem {
                let attrs: [String: Any] = [kSecValueData as String: data]
                _ = SecItemUpdate(baseQuery(includeAccessGroup: false) as CFDictionary, attrs as CFDictionary)
            }
        }
    }

    private func delete(account: String) {
        func query(includeAccessGroup: Bool) -> [String: Any] {
            var q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            if includeAccessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
            return q
        }

        SecItemDelete(query(includeAccessGroup: true) as CFDictionary)
        SecItemDelete(query(includeAccessGroup: false) as CFDictionary)
    }
}
