import Foundation
import LocalAuthentication
import Security

public struct KeychainStore {
    public enum AuthenticationUIBehavior {
        case allow
        case fail
    }

    private let service = "TrackSaverSpotify"
    private let accessTokenAccount = "accessToken"
    private let refreshTokenAccount = "refreshToken"
    private let expirationAccount = "accessTokenExpiration"
    // Shared access group for app + extensions (falls vorhanden). Fällt bei fehlender Entitlement sauber zurück.
    private let accessGroup = "8W4U9DBYVS.group.dyonisosfergadiotis.tracksaver"

    public init() {}

    private var prefersDataProtectionKeychain: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }

    // MARK: - Public API

    public func hasAuthTokens(authenticationUI: AuthenticationUIBehavior = .allow) -> Bool {
        readAccessToken(authenticationUI: authenticationUI) != nil ||
        readRefreshToken(authenticationUI: authenticationUI) != nil
    }

    public func readAccessToken(authenticationUI: AuthenticationUIBehavior = .allow) -> String? {
        readString(account: accessTokenAccount, authenticationUI: authenticationUI)
    }

    public func readRefreshToken(authenticationUI: AuthenticationUIBehavior = .allow) -> String? {
        readString(account: refreshTokenAccount, authenticationUI: authenticationUI)
    }

    public func readAccessTokenExpiration(authenticationUI: AuthenticationUIBehavior = .allow) -> Date? {
        guard let raw = readString(account: expirationAccount, authenticationUI: authenticationUI),
              let interval = TimeInterval(raw) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    public func saveAccessToken(_ token: String) {
        _ = saveString(token, account: accessTokenAccount)
    }

    public func saveRefreshToken(_ token: String) {
        _ = saveString(token, account: refreshTokenAccount)
    }

    public func saveAccessTokenExpiration(_ date: Date) {
        _ = saveString(String(date.timeIntervalSince1970), account: expirationAccount)
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

    public func migrateLegacyTokensIfNeeded(authenticationUI: AuthenticationUIBehavior = .allow) {
        migrateLegacyStringIfNeeded(account: accessTokenAccount, authenticationUI: authenticationUI)
        migrateLegacyStringIfNeeded(account: refreshTokenAccount, authenticationUI: authenticationUI)
        migrateLegacyStringIfNeeded(account: expirationAccount, authenticationUI: authenticationUI)
    }

    // MARK: - Helpers

    private func readString(account: String, authenticationUI: AuthenticationUIBehavior) -> String? {
        if let sharedValue = readStoredString(
            account: account,
            includeAccessGroup: true,
            synchronizable: kSecAttrSynchronizableAny,
            useDataProtectionKeychain: prefersDataProtectionKeychain,
            authenticationUI: authenticationUI
        ) {
            return sharedValue
        }
        if let sharedValue = readStoredString(
            account: account,
            includeAccessGroup: true,
            synchronizable: nil,
            useDataProtectionKeychain: prefersDataProtectionKeychain,
            authenticationUI: authenticationUI
        ) {
            return sharedValue
        }
        if let localValue = readStoredString(
            account: account,
            includeAccessGroup: false,
            synchronizable: kSecAttrSynchronizableAny,
            useDataProtectionKeychain: prefersDataProtectionKeychain,
            authenticationUI: authenticationUI
        ) {
            return localValue
        }
        return readStoredString(
            account: account,
            includeAccessGroup: false,
            synchronizable: nil,
            useDataProtectionKeychain: prefersDataProtectionKeychain,
            authenticationUI: authenticationUI
        )
    }

    private func migrateLegacyStringIfNeeded(account: String, authenticationUI: AuthenticationUIBehavior) {
        guard readString(account: account, authenticationUI: authenticationUI) == nil else { return }
        guard let legacyValue = readLegacyString(
            account: account,
            includeAccessGroup: true,
            authenticationUI: authenticationUI
        ) ?? readLegacyString(
            account: account,
            includeAccessGroup: false,
            authenticationUI: authenticationUI
        ) else {
            return
        }

        let status = saveString(legacyValue, account: account)
#if os(macOS)
        if status == errSecSuccess {
            deleteLegacy(account: account)
        }
#endif
    }

    private func readLegacyString(
        account: String,
        includeAccessGroup: Bool,
        authenticationUI: AuthenticationUIBehavior
    ) -> String? {
        readStoredString(
            account: account,
            includeAccessGroup: includeAccessGroup,
            synchronizable: nil,
            useDataProtectionKeychain: false,
            authenticationUI: authenticationUI
        )
    }

    private func readStoredString(
        account: String,
        includeAccessGroup: Bool,
        synchronizable: CFTypeRef?,
        useDataProtectionKeychain: Bool,
        authenticationUI: AuthenticationUIBehavior
    ) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            baseQuery(
                account: account,
                includeAccessGroup: includeAccessGroup,
                synchronizable: synchronizable,
                useDataProtectionKeychain: useDataProtectionKeychain,
                returnData: true,
                authenticationUI: authenticationUI
            ) as CFDictionary,
            &item
        )
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private func saveString(_ value: String, account: String) -> OSStatus {
        guard let data = value.data(using: .utf8) else { return errSecParam }

        let primaryStatus = saveString(
            data,
            account: account,
            includeAccessGroup: true,
            synchronizable: kCFBooleanTrue,
            useDataProtectionKeychain: prefersDataProtectionKeychain
        )
        let sharedLocalStatus = saveString(
            data,
            account: account,
            includeAccessGroup: true,
            synchronizable: nil,
            useDataProtectionKeychain: prefersDataProtectionKeychain
        )
        let appLocalStatus = saveString(
            data,
            account: account,
            includeAccessGroup: false,
            synchronizable: nil,
            useDataProtectionKeychain: prefersDataProtectionKeychain
        )

        if primaryStatus == errSecSuccess { return primaryStatus }
        if sharedLocalStatus == errSecSuccess { return sharedLocalStatus }
        if appLocalStatus == errSecSuccess { return appLocalStatus }
        return primaryStatus
    }

    @discardableResult
    private func saveString(
        _ data: Data,
        account: String,
        includeAccessGroup: Bool,
        synchronizable: CFTypeRef?,
        useDataProtectionKeychain: Bool
    ) -> OSStatus {
        var status = addOrUpdate(
            data,
            account: account,
            includeAccessGroup: includeAccessGroup,
            synchronizable: synchronizable,
            useDataProtectionKeychain: useDataProtectionKeychain
        )
        if status == errSecDuplicateItem {
            status = update(
                data,
                account: account,
                includeAccessGroup: includeAccessGroup,
                synchronizable: synchronizable,
                useDataProtectionKeychain: useDataProtectionKeychain
            )
        }
        return status
    }

    private func delete(account: String) {
        deleteStoredItems(account: account, useDataProtectionKeychain: prefersDataProtectionKeychain)
#if os(macOS)
        deleteLegacy(account: account)
#endif
    }

    private func deleteStoredItems(account: String, useDataProtectionKeychain: Bool) {
        SecItemDelete(
            baseQuery(
                account: account,
                includeAccessGroup: true,
                synchronizable: kCFBooleanTrue,
                useDataProtectionKeychain: useDataProtectionKeychain
            ) as CFDictionary
        )
        SecItemDelete(
            baseQuery(
                account: account,
                includeAccessGroup: true,
                synchronizable: nil,
                useDataProtectionKeychain: useDataProtectionKeychain
            ) as CFDictionary
        )
        SecItemDelete(
            baseQuery(
                account: account,
                includeAccessGroup: false,
                synchronizable: kCFBooleanTrue,
                useDataProtectionKeychain: useDataProtectionKeychain
            ) as CFDictionary
        )
        SecItemDelete(
            baseQuery(
                account: account,
                includeAccessGroup: false,
                synchronizable: nil,
                useDataProtectionKeychain: useDataProtectionKeychain
            ) as CFDictionary
        )
    }

    private func deleteLegacy(account: String) {
        SecItemDelete(
            baseQuery(
                account: account,
                includeAccessGroup: true,
                synchronizable: nil,
                useDataProtectionKeychain: false
            ) as CFDictionary
        )
        SecItemDelete(
            baseQuery(
                account: account,
                includeAccessGroup: false,
                synchronizable: nil,
                useDataProtectionKeychain: false
            ) as CFDictionary
        )
    }

    private func addOrUpdate(
        _ data: Data,
        account: String,
        includeAccessGroup: Bool,
        synchronizable: CFTypeRef?,
        useDataProtectionKeychain: Bool
    ) -> OSStatus {
        var query = baseQuery(
            account: account,
            includeAccessGroup: includeAccessGroup,
            synchronizable: synchronizable,
            useDataProtectionKeychain: useDataProtectionKeychain
        )
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil)
    }

    private func update(
        _ data: Data,
        account: String,
        includeAccessGroup: Bool,
        synchronizable: CFTypeRef?,
        useDataProtectionKeychain: Bool
    ) -> OSStatus {
        let attrs: [String: Any] = [kSecValueData as String: data]
        return SecItemUpdate(
            baseQuery(
                account: account,
                includeAccessGroup: includeAccessGroup,
                synchronizable: synchronizable,
                useDataProtectionKeychain: useDataProtectionKeychain
            ) as CFDictionary,
            attrs as CFDictionary
        )
    }

    private func shouldRetryWithoutSynchronizable(_ status: OSStatus) -> Bool {
        switch status {
        case errSecMissingEntitlement,
             errSecNoSuchKeychain,
             errSecInteractionNotAllowed,
             errSecItemNotFound,
             errSecNotAvailable,
             errSecParam:
            return true
        default:
            return false
        }
    }

    private func shouldRetryWithoutAccessGroup(_ status: OSStatus) -> Bool {
        shouldRetryWithoutSynchronizable(status)
    }

    private func baseQuery(
        account: String,
        includeAccessGroup: Bool,
        synchronizable: CFTypeRef?,
        useDataProtectionKeychain: Bool,
        returnData: Bool = false,
        authenticationUI: AuthenticationUIBehavior = .allow
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if includeAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        if let synchronizable {
            query[kSecAttrSynchronizable as String] = synchronizable
        }
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        if returnData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
#if os(macOS)
        if authenticationUI == .fail {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
#endif
        return query
    }
}
