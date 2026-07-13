import XCTest
@testable import CodexSwitchCore

final class CodexConfigEditorTests: XCTestCase {
    func testApplyCustomBaseURLWritesTopLevelKeysBeforeTables() throws {
        let file = try temporaryDirectory().appendingPathComponent("config.toml")
        try """
        model = "gpt-5.5"

        [projects."/tmp/demo"]
        trust_level = "trusted"
        """.write(to: file, atomically: true, encoding: .utf8)
        let editor = CodexConfigEditor(configFile: file)

        try editor.apply(baseURL: URL(string: "https://hk.rootflowai.com/v1")!)

        let contents = try String(contentsOf: file, encoding: .utf8)
        XCTAssertTrue(contents.contains("model = \"gpt-5.5\""))
        XCTAssertTrue(contents.contains("cli_auth_credentials_store = \"file\""))
        XCTAssertTrue(contents.contains("openai_base_url = \"https://hk.rootflowai.com/v1\""))
        XCTAssertTrue(contents.contains("[projects.\"/tmp/demo\"]"))
        XCTAssertLessThan(
            contents.range(of: "openai_base_url")!.lowerBound,
            contents.range(of: "[projects.")!.lowerBound
        )
    }

    func testApplyDefaultRemovesBaseURLButKeepsFileCredentialStore() throws {
        let file = try temporaryDirectory().appendingPathComponent("config.toml")
        try """
        model = "gpt-5.5"
        openai_base_url = "https://old.example.com/v1"
        cli_auth_credentials_store = "keyring"

        [mcp_servers.node_repl]
        command = "node"
        """.write(to: file, atomically: true, encoding: .utf8)
        let editor = CodexConfigEditor(configFile: file)

        try editor.apply(baseURL: nil)

        let contents = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(contents.contains("old.example.com"))
        XCTAssertTrue(contents.contains("cli_auth_credentials_store = \"file\""))
        XCTAssertTrue(contents.contains("[mcp_servers.node_repl]"))
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexSwitchTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

