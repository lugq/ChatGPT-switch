import Foundation

public final class CodexConfigEditor {
    private let configFile: URL
    private let fileManager: FileManager

    public init(configFile: URL, fileManager: FileManager = .default) {
        self.configFile = configFile
        self.fileManager = fileManager
    }

    public func apply(baseURL: URL?) throws {
        let original = try readConfig()
        let edited = editConfig(original, baseURL: baseURL)
        try fileManager.createDirectory(
            at: configFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try edited.write(to: configFile, atomically: true, encoding: .utf8)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFile.path)
    }

    private func readConfig() throws -> String {
        guard fileManager.fileExists(atPath: configFile.path) else {
            return ""
        }
        return try String(contentsOf: configFile, encoding: .utf8)
    }

    private func editConfig(_ contents: String, baseURL: URL?) -> String {
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var filtered: [String] = []
        var isTopLevel = true

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                isTopLevel = false
            }

            if isTopLevel && isManagedTopLevelKey(trimmed) {
                continue
            }

            filtered.append(line)
        }

        let insertionIndex = filtered.firstIndex { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("[")
        } ?? filtered.count

        var managedLines = [
            #"cli_auth_credentials_store = "file""#
        ]
        if let baseURL {
            managedLines.append(#"openai_base_url = "\#(escapeTOMLString(baseURL.absoluteString))""#)
        }

        if insertionIndex > 0,
           insertionIndex <= filtered.count,
           filtered[insertionIndex - 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            managedLines.append("")
        }

        filtered.insert(contentsOf: managedLines, at: insertionIndex)

        while filtered.first?.isEmpty == true {
            filtered.removeFirst()
        }

        return filtered.joined(separator: "\n") + "\n"
    }

    private func isManagedTopLevelKey(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("openai_base_url")
            || trimmedLine.hasPrefix("cli_auth_credentials_store")
    }

    private func escapeTOMLString(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\"#, with: #"\\"#)
            .replacingOccurrences(of: #"""#, with: #"\""#)
    }
}

