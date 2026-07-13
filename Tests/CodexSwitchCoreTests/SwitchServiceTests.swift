import XCTest
@testable import CodexSwitchCore

final class SwitchServiceTests: XCTestCase {
    func testSwitchingToCustomProfileLeavesHistoryFilesUntouched() throws {
        let fixture = try Fixture()
        let profile = CodexProfile(
            id: "codex-plus",
            name: "Codex-Plus",
            kind: .openAICompatible,
            baseURL: URL(string: "https://hk.rootflowai.com/v1")!,
            iconName: "sparkle"
        )
        try fixture.profileStore.save(ProfileState(currentProfileID: "default", profiles: [.defaultProfile(), profile]))
        try fixture.secrets.setString("sk-test_abcdefghijklmnopqrstuvwxyz0123456789", forKey: profile.secretKey)
        try Data(#"{"auth_mode":"chatgpt","tokens":{"access_token":"old"}}"#.utf8).write(to: fixture.paths.authFile)
        try #"model = "gpt-5.5""#.write(to: fixture.paths.configFile, atomically: true, encoding: .utf8)
        try fixture.writeHistorySentinels()

        try fixture.service.switchToProfile(id: "codex-plus")

        XCTAssertEqual(fixture.cli.loginCalls, ["sk-test_abcdefghijklmnopqrstuvwxyz0123456789"])
        let config = try String(contentsOf: fixture.paths.configFile, encoding: .utf8)
        XCTAssertTrue(config.contains(#"openai_base_url = "https://hk.rootflowai.com/v1""#))
        XCTAssertEqual(try fixture.readHistorySentinels(), ["session": "keep-session", "archive": "keep-archive", "history": "keep-history"])
    }

    func testSwitchFailureRestoresAuthAndConfig() throws {
        let fixture = try Fixture()
        fixture.cli.errorToThrow = CodexCLIError.failed(status: 2, output: "login failed")
        let profile = CodexProfile(
            id: "codex-plus",
            name: "Codex-Plus",
            kind: .openAICompatible,
            baseURL: URL(string: "https://hk.rootflowai.com/v1")!,
            iconName: "sparkle"
        )
        try fixture.profileStore.save(ProfileState(currentProfileID: "default", profiles: [.defaultProfile(), profile]))
        try fixture.secrets.setString("sk-test_abcdefghijklmnopqrstuvwxyz0123456789", forKey: profile.secretKey)
        let originalAuth = #"{"auth_mode":"chatgpt","tokens":{"access_token":"old"}}"#
        let originalConfig = #"model = "gpt-5.5""#
        try Data(originalAuth.utf8).write(to: fixture.paths.authFile)
        try originalConfig.write(to: fixture.paths.configFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try fixture.service.switchToProfile(id: "codex-plus"))

        XCTAssertEqual(try String(contentsOf: fixture.paths.authFile, encoding: .utf8), originalAuth)
        XCTAssertEqual(try String(contentsOf: fixture.paths.configFile, encoding: .utf8), originalConfig)
        XCTAssertEqual(try fixture.profileStore.load().currentProfileID, "default")
    }

    func testSwitchingToDefaultRestoresSavedChatGPTSnapshotAndRemovesBaseURL() throws {
        let fixture = try Fixture()
        let profile = CodexProfile(
            id: "codex-plus",
            name: "Codex-Plus",
            kind: .openAICompatible,
            baseURL: URL(string: "https://hk.rootflowai.com/v1")!,
            iconName: "sparkle"
        )
        try fixture.profileStore.save(ProfileState(currentProfileID: "codex-plus", profiles: [.defaultProfile(), profile]))
        try fixture.secrets.setData(Data(#"{"auth_mode":"chatgpt","tokens":{"access_token":"default"}}"#.utf8), forKey: CodexProfile.defaultProfile().secretKey)
        try Data(#"{"auth_mode":"apikey","OPENAI_API_KEY":"sk-custom"}"#.utf8).write(to: fixture.paths.authFile)
        try """
        model = "gpt-5.5"
        openai_base_url = "https://hk.rootflowai.com/v1"
        """.write(to: fixture.paths.configFile, atomically: true, encoding: .utf8)

        try fixture.service.switchToProfile(id: "default")

        let auth = try String(contentsOf: fixture.paths.authFile, encoding: .utf8)
        let config = try String(contentsOf: fixture.paths.configFile, encoding: .utf8)
        XCTAssertTrue(auth.contains(#""auth_mode":"chatgpt""#))
        XCTAssertFalse(config.contains("openai_base_url"))
        XCTAssertEqual(try fixture.profileStore.load().currentProfileID, "default")
    }
}

private final class FakeCodexCLI: CodexCLI {
    var loginCalls: [String] = []
    var errorToThrow: Error?

    func loginWithAPIKey(_ apiKey: String, codexHome: URL) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        loginCalls.append(apiKey)
        let authFile = codexHome.appendingPathComponent("auth.json")
        try Data(#"{"auth_mode":"apikey","OPENAI_API_KEY":"\#(apiKey)"}"#.utf8).write(to: authFile)
    }

    func loginStatus(codexHome: URL) throws -> String {
        "Logged in"
    }
}

private struct Fixture {
    let root: URL
    let appData: URL
    let paths: CodexPaths
    let profileStore: ProfileStore
    let secrets: InMemorySecretStore
    let cli: FakeCodexCLI
    let service: SwitchService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexSwitchTests")
            .appendingPathComponent(UUID().uuidString)
        appData = root.appendingPathComponent("app-data")
        let codexHome = root.appendingPathComponent("codex-home")
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        paths = CodexPaths(codexHome: codexHome)
        profileStore = ProfileStore(rootDirectory: appData)
        secrets = InMemorySecretStore()
        cli = FakeCodexCLI()
        service = SwitchService(
            profileStore: profileStore,
            secretStore: secrets,
            codexPaths: paths,
            appDataDirectory: appData,
            codexCLI: cli
        )
    }

    func writeHistorySentinels() throws {
        try FileManager.default.createDirectory(at: paths.sessionsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.archivedSessionsDirectory, withIntermediateDirectories: true)
        try "keep-session".write(to: paths.sessionsDirectory.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8)
        try "keep-archive".write(to: paths.archivedSessionsDirectory.appendingPathComponent("archive.jsonl"), atomically: true, encoding: .utf8)
        try "keep-history".write(to: paths.historyFile, atomically: true, encoding: .utf8)
    }

    func readHistorySentinels() throws -> [String: String] {
        [
            "session": try String(contentsOf: paths.sessionsDirectory.appendingPathComponent("session.jsonl"), encoding: .utf8),
            "archive": try String(contentsOf: paths.archivedSessionsDirectory.appendingPathComponent("archive.jsonl"), encoding: .utf8),
            "history": try String(contentsOf: paths.historyFile, encoding: .utf8)
        ]
    }
}

