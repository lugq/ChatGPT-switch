import XCTest
@testable import CodexSwitchCore

final class ProfileStoreTests: XCTestCase {
    func testMissingProfileFileLoadsDefaultState() throws {
        let directory = try temporaryDirectory()
        let store = ProfileStore(rootDirectory: directory)

        let state = try store.load()

        XCTAssertEqual(state.currentProfileID, "default")
        XCTAssertEqual(state.profiles, [.defaultProfile()])
    }

    func testSavingCustomProfileDoesNotWriteTokenToProfilesJSON() throws {
        let directory = try temporaryDirectory()
        let store = ProfileStore(rootDirectory: directory)
        let profile = CodexProfile(
            id: "codex-plus",
            name: "Codex-Plus",
            kind: .openAICompatible,
            baseURL: URL(string: "https://hk.rootflowai.com/v1")!,
            iconName: "sparkle"
        )

        try store.save(ProfileState(currentProfileID: "codex-plus", profiles: [.defaultProfile(), profile]))

        let rawJSON = try String(contentsOf: directory.appendingPathComponent("profiles.json"), encoding: .utf8)
        XCTAssertTrue(rawJSON.contains("Codex-Plus"))
        XCTAssertTrue(rawJSON.contains("hk.rootflowai.com"))
        XCTAssertTrue(rawJSON.contains("v1"))
        XCTAssertFalse(rawJSON.contains("sk-"))
        XCTAssertFalse(rawJSON.localizedCaseInsensitiveContains("token"))
    }

    func testInMemorySecretStoreRoundTripsData() throws {
        let store = InMemorySecretStore()
        let data = Data("secret-value".utf8)

        try store.setData(data, forKey: "profile.codex-plus.api-token")

        XCTAssertEqual(try store.data(forKey: "profile.codex-plus.api-token"), data)
        try store.deleteData(forKey: "profile.codex-plus.api-token")
        XCTAssertNil(try store.data(forKey: "profile.codex-plus.api-token"))
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexSwitchTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
