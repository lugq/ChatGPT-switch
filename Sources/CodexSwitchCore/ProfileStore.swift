import Foundation

public struct ProfileState: Codable, Equatable {
    public var currentProfileID: String
    public var profiles: [CodexProfile]

    public init(currentProfileID: String, profiles: [CodexProfile]) {
        self.currentProfileID = currentProfileID
        self.profiles = profiles
    }

    public static func defaultState() -> ProfileState {
        ProfileState(currentProfileID: "default", profiles: [.defaultProfile()])
    }
}

public final class ProfileStore {
    private let rootDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public var profilesFile: URL {
        rootDirectory.appendingPathComponent("profiles.json")
    }

    public func load() throws -> ProfileState {
        guard fileManager.fileExists(atPath: profilesFile.path) else {
            return .defaultState()
        }

        let data = try Data(contentsOf: profilesFile)
        var state = try decoder.decode(ProfileState.self, from: data)
        if !state.profiles.contains(where: { $0.id == "default" }) {
            state.profiles.insert(.defaultProfile(), at: 0)
        }
        if !state.profiles.contains(where: { $0.id == state.currentProfileID }) {
            state.currentProfileID = "default"
        }
        return state
    }

    public func save(_ state: ProfileState) throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let data = try encoder.encode(state)
        try data.write(to: profilesFile, options: [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: profilesFile.path)
    }
}

