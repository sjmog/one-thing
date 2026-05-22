import Foundation
import Security

protocol SecretStore {
    func readPassphrase() -> String?
    func savePassphrase(_ passphrase: String) throws
    func deletePassphrase()
}

enum KeychainError: Error {
    case unhandledStatus(OSStatus)
}

struct KeychainStore: SecretStore {
    private let service = "com.sjmog.onething.sync"
    private let account = "passphrase"

    func readPassphrase() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func savePassphrase(_ passphrase: String) throws {
        let data = Data(passphrase.utf8)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess { return }

        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecSuccess { return }
            throw KeychainError.unhandledStatus(updateStatus)
        }

        throw KeychainError.unhandledStatus(status)
    }

    func deletePassphrase() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
