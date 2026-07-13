import Foundation

public enum CodexCLIError: Error, Equatable, LocalizedError {
    case executableNotFound
    case failed(status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Codex CLI executable was not found."
        case .failed(let status, let output):
            return "Codex CLI failed with status \(status): \(output)"
        }
    }
}

public protocol CodexCLI {
    func loginWithAPIKey(_ apiKey: String, codexHome: URL) throws
    func loginStatus(codexHome: URL) throws -> String
}

public final class ProcessCodexCLI: CodexCLI {
    private let executableURL: URL

    public init(executableURL: URL? = nil) throws {
        if let executableURL {
            self.executableURL = executableURL
        } else if let resolved = Self.resolveExecutable() {
            self.executableURL = resolved
        } else {
            throw CodexCLIError.executableNotFound
        }
    }

    public func loginWithAPIKey(_ apiKey: String, codexHome: URL) throws {
        _ = try run(args: ["login", "--with-api-key"], stdin: apiKey, codexHome: codexHome)
    }

    public func loginStatus(codexHome: URL) throws -> String {
        try run(args: ["login", "status"], stdin: nil, codexHome: codexHome)
    }

    public static func resolveExecutable() -> URL? {
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func run(args: [String], stdin: String?, codexHome: URL) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = args

        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHome.path
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let stdin {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            try process.run()
            inputPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try inputPipe.fileHandleForWriting.close()
        } else {
            try process.run()
        }

        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let combined = String(decoding: output + error, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw CodexCLIError.failed(status: process.terminationStatus, output: combined)
        }

        return combined
    }
}

