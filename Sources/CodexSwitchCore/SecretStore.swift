import Foundation

#if canImport(Security)
import Security
#endif

public enum SecretStoreError: Error, Equatable, LocalizedError {
    case unavailable
    case unexpectedStatus(Int32)
    case invalidStringData

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Keychain is unavailable on this platform."
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .invalidStringData:
            return "Secret data is not valid UTF-8."
        }
    }
}

public protocol SecretStore {
    func data(forKey key: String) throws -> Data?
    func setData(_ data: Data, forKey key: String) throws
    func deleteData(forKey key: String) throws
}

public extension SecretStore {
    func string(forKey key: String) throws -> String? {
        guard let data = try data(forKey: key) else {
            return nil
        }
        guard let value = String(data: data, encoding: .utf8) else {
            throw SecretStoreError.invalidStringData
        }
        return value
    }

    func setString(_ value: String, forKey key: String) throws {
        try setData(Data(value.utf8), forKey: key)
    }
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) throws -> Data? {
        values[key]
    }

    public func setData(_ data: Data, forKey key: String) throws {
        values[key] = data
    }

    public func deleteData(forKey key: String) throws {
        values.removeValue(forKey: key)
    }
}

public final class KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String = "ChatGPT-switch") {
        self.service = service
    }

    public func data(forKey key: String) throws -> Data? {
        #if canImport(Security)
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecretStoreError.unexpectedStatus(status)
        }
        return item as? Data
        #else
        throw SecretStoreError.unavailable
        #endif
    }

    public func setData(_ data: Data, forKey key: String) throws {
        #if canImport(Security)
        try deleteData(forKey: key)
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretStoreError.unexpectedStatus(status)
        }
        #else
        throw SecretStoreError.unavailable
        #endif
    }

    public func deleteData(forKey key: String) throws {
        #if canImport(Security)
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
        #else
        throw SecretStoreError.unavailable
        #endif
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        #if canImport(Security)
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        #else
        [:]
        #endif
    }
}
