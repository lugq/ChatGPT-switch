import Foundation

public struct CodexPaths: Equatable {
    public var codexHome: URL

    public init(codexHome: URL) {
        self.codexHome = codexHome
    }

    public static func defaultPaths() -> CodexPaths {
        CodexPaths(codexHome: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"))
    }

    public var authFile: URL {
        codexHome.appendingPathComponent("auth.json")
    }

    public var configFile: URL {
        codexHome.appendingPathComponent("config.toml")
    }

    public var sessionsDirectory: URL {
        codexHome.appendingPathComponent("sessions")
    }

    public var archivedSessionsDirectory: URL {
        codexHome.appendingPathComponent("archived_sessions")
    }

    public var historyFile: URL {
        codexHome.appendingPathComponent("history.jsonl")
    }
}

