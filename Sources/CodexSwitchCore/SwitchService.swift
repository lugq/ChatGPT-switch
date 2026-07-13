import Foundation

public enum SwitchServiceError: Error, Equatable, LocalizedError {
    case profileNotFound(String)
    case missingBaseURL(String)
    case missingToken(String)
    case missingDefaultSnapshot

    public var errorDescription: String? {
        switch self {
        case .profileNotFound(let id):
            return "Profile not found: \(id)"
        case .missingBaseURL(let id):
            return "Profile is missing a base URL: \(id)"
        case .missingToken(let id):
            return "Profile is missing its API token: \(id)"
        case .missingDefaultSnapshot:
            return "Default ChatGPT auth snapshot is missing."
        }
    }
}

public final class SwitchService {
    private let profileStore: ProfileStore
    private let secretStore: SecretStore
    private let codexPaths: CodexPaths
    private let appDataDirectory: URL
    private let codexCLI: CodexCLI
    private let fileManager: FileManager

    public init(
        profileStore: ProfileStore,
        secretStore: SecretStore,
        codexPaths: CodexPaths,
        appDataDirectory: URL,
        codexCLI: CodexCLI,
        fileManager: FileManager = .default
    ) {
        self.profileStore = profileStore
        self.secretStore = secretStore
        self.codexPaths = codexPaths
        self.appDataDirectory = appDataDirectory
        self.codexCLI = codexCLI
        self.fileManager = fileManager
    }

    public func switchToProfile(id targetID: String) throws {
        var state = try profileStore.load()
        guard let target = state.profiles.first(where: { $0.id == targetID }) else {
            throw SwitchServiceError.profileNotFound(targetID)
        }

        let backup = try createBackup()

        do {
            try captureOutgoingDefaultSnapshotIfNeeded(currentProfileID: state.currentProfileID)

            switch target.kind {
            case .chatGPTDefault:
                try switchToDefault()
            case .openAICompatible:
                try switchToOpenAICompatible(target)
            }

            state.currentProfileID = target.id
            try profileStore.save(state)
        } catch {
            try restoreBackup(backup)
            throw error
        }
    }

    private func switchToDefault() throws {
        let defaultKey = CodexProfile.defaultProfile().secretKey
        let snapshot = try secretStore.data(forKey: defaultKey) ?? currentAuthData()
        guard let snapshot else {
            throw SwitchServiceError.missingDefaultSnapshot
        }

        try write(snapshot, to: codexPaths.authFile)
        try CodexConfigEditor(configFile: codexPaths.configFile, fileManager: fileManager).apply(baseURL: nil)
    }

    private func switchToOpenAICompatible(_ profile: CodexProfile) throws {
        guard let baseURL = profile.baseURL else {
            throw SwitchServiceError.missingBaseURL(profile.id)
        }
        guard let token = try secretStore.string(forKey: profile.secretKey), token.isEmpty == false else {
            throw SwitchServiceError.missingToken(profile.id)
        }

        try CodexConfigEditor(configFile: codexPaths.configFile, fileManager: fileManager).apply(baseURL: baseURL)
        try codexCLI.loginWithAPIKey(token, codexHome: codexPaths.codexHome)
    }

    private func captureOutgoingDefaultSnapshotIfNeeded(currentProfileID: String) throws {
        guard currentProfileID == "default", let data = currentAuthData() else {
            return
        }
        try secretStore.setData(data, forKey: CodexProfile.defaultProfile().secretKey)
    }

    private func currentAuthData() -> Data? {
        guard fileManager.fileExists(atPath: codexPaths.authFile.path) else {
            return nil
        }
        return try? Data(contentsOf: codexPaths.authFile)
    }

    private func write(_ data: Data, to file: URL) throws {
        try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func createBackup() throws -> FileBackup {
        let backup = FileBackup(
            authData: readIfExists(codexPaths.authFile),
            configData: readIfExists(codexPaths.configFile)
        )

        let backupDirectory = appDataDirectory
            .appendingPathComponent("backups")
            .appendingPathComponent(Self.timestamp())
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        if let authData = backup.authData {
            try authData.write(to: backupDirectory.appendingPathComponent("auth.json"), options: [.atomic])
        }
        if let configData = backup.configData {
            try configData.write(to: backupDirectory.appendingPathComponent("config.toml"), options: [.atomic])
        }

        return backup
    }

    private func restoreBackup(_ backup: FileBackup) throws {
        try restore(backup.authData, to: codexPaths.authFile)
        try restore(backup.configData, to: codexPaths.configFile)
    }

    private func restore(_ data: Data?, to file: URL) throws {
        if let data {
            try write(data, to: file)
        } else if fileManager.fileExists(atPath: file.path) {
            try fileManager.removeItem(at: file)
        }
    }

    private func readIfExists(_ file: URL) -> Data? {
        guard fileManager.fileExists(atPath: file.path) else {
            return nil
        }
        return try? Data(contentsOf: file)
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }
}

private struct FileBackup {
    var authData: Data?
    var configData: Data?
}

