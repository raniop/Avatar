import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.rani.Avatar"

    private init() {}

    func saveAccessToken(_ token: String) {
        save(key: "accessToken", value: token)
    }

    func getAccessToken() -> String? {
        load(key: "accessToken")
    }

    func saveRefreshToken(_ token: String) {
        save(key: "refreshToken", value: token)
    }

    func getRefreshToken() -> String? {
        load(key: "refreshToken")
    }

    func clearTokens() {
        delete(key: "accessToken")
        delete(key: "refreshToken")
    }

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
