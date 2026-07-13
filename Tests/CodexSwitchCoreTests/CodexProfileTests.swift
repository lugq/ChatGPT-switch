import XCTest
@testable import CodexSwitchCore

final class CodexProfileTests: XCTestCase {
    func testDefaultProfileRepresentsOfficialChatGPTAccount() {
        let profile = CodexProfile.defaultProfile()

        XCTAssertEqual(profile.id, "default")
        XCTAssertEqual(profile.name, "default")
        XCTAssertEqual(profile.kind, .chatGPTDefault)
        XCTAssertNil(profile.baseURL)
        XCTAssertEqual(profile.displaySubtitle, "未配置官网地址")
    }

    func testCustomProfileStoresBaseURLButNotToken() {
        let profile = CodexProfile(
            id: "codex-plus",
            name: "Codex-Plus",
            kind: .openAICompatible,
            baseURL: URL(string: "https://hk.rootflowai.com/v1")!,
            iconName: "sparkle"
        )

        XCTAssertEqual(profile.displaySubtitle, "https://hk.rootflowai.com/v1")
        XCTAssertEqual(profile.secretKey, "profile.codex-plus.api-token")
    }
}

