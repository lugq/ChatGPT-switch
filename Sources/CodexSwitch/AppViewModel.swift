import Foundation
import SwiftUI
import CodexSwitchCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var profiles: [CodexProfile] = []
    @Published private(set) var currentProfileID = "default"
    @Published var selectedProfileID = "default"
    @Published var statusMessage = "Ready"
    @Published var isBusy = false
    @Published var editorDraft: ProfileDraft?

    private let profileStore: ProfileStore
    private let secretStore: SecretStore
    private let switchService: SwitchService

    init(profileStore: ProfileStore, secretStore: SecretStore, switchService: SwitchService) {
        self.profileStore = profileStore
        self.secretStore = secretStore
        self.switchService = switchService
        load()
    }

    static func production() -> AppViewModel {
        let appData = AppDirectories.applicationSupport
        let paths = CodexPaths.defaultPaths()
        let profileStore = ProfileStore(rootDirectory: appData)
        let secretStore = KeychainSecretStore(service: "ChatGPT-switch")
        let cli: CodexCLI
        do {
            cli = try ProcessCodexCLI()
        } catch {
            cli = MissingCodexCLI()
        }
        let service = SwitchService(
            profileStore: profileStore,
            secretStore: secretStore,
            codexPaths: paths,
            appDataDirectory: appData,
            codexCLI: cli
        )
        return AppViewModel(profileStore: profileStore, secretStore: secretStore, switchService: service)
    }

    func load() {
        do {
            let state = try profileStore.load()
            profiles = state.profiles
            currentProfileID = state.currentProfileID
            selectedProfileID = state.currentProfileID
        } catch {
            statusMessage = "加载失败：\(error.localizedDescription)"
            profiles = [.defaultProfile()]
            currentProfileID = "default"
            selectedProfileID = "default"
        }
    }

    func beginAddProfile() {
        editorDraft = ProfileDraft()
    }

    func beginEditSelectedProfile() {
        guard let profile = selectedProfile, profile.kind != .chatGPTDefault else {
            return
        }
        editorDraft = ProfileDraft(profile: profile)
    }

    func duplicateSelectedProfile() {
        guard let profile = selectedProfile, profile.kind == .openAICompatible else {
            return
        }
        var draft = ProfileDraft(profile: profile)
        draft.id = makeUniqueID(from: profile.name + "-copy")
        draft.name = profile.name + " Copy"
        draft.token = ""
        editorDraft = draft
    }

    func deleteSelectedProfile() {
        guard let profile = selectedProfile, profile.kind != .chatGPTDefault else {
            return
        }
        do {
            var state = try profileStore.load()
            state.profiles.removeAll { $0.id == profile.id }
            if state.currentProfileID == profile.id {
                state.currentProfileID = "default"
            }
            try secretStore.deleteData(forKey: profile.secretKey)
            try profileStore.save(state)
            load()
            statusMessage = "已删除 \(profile.name)"
        } catch {
            statusMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    func saveDraft(_ draft: ProfileDraft) {
        guard let baseURL = URL(string: draft.baseURL), baseURL.scheme?.hasPrefix("http") == true else {
            statusMessage = "Base URL 无效"
            return
        }
        let profileID = draft.id.isEmpty ? makeUniqueID(from: draft.name) : draft.id
        let profile = CodexProfile(
            id: profileID,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : draft.name,
            kind: .openAICompatible,
            baseURL: baseURL,
            iconName: draft.iconName
        )

        do {
            var state = try profileStore.load()
            if let index = state.profiles.firstIndex(where: { $0.id == profile.id }) {
                state.profiles[index] = profile
            } else {
                state.profiles.insert(profile, at: max(0, state.profiles.count - 1))
            }
            if draft.token.isEmpty == false {
                try secretStore.setString(draft.token, forKey: profile.secretKey)
            }
            try profileStore.save(state)
            editorDraft = nil
            load()
            selectedProfileID = profile.id
            statusMessage = "已保存 \(profile.name)"
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func switchToSelectedProfile() {
        let targetID = selectedProfileID
        guard profiles.contains(where: { $0.id == targetID }) else {
            return
        }

        isBusy = true
        statusMessage = "切换中..."
        do {
            try switchService.switchToProfile(id: targetID)
            load()
            selectedProfileID = targetID
            statusMessage = "已切换到 \(selectedProfile?.name ?? targetID)"
        } catch {
            statusMessage = "切换失败：\(error.localizedDescription)"
        }
        isBusy = false
    }

    func testSelectedProfile() {
        guard let profile = selectedProfile else {
            return
        }
        if profile.kind == .chatGPTDefault {
            statusMessage = "default 使用 Codex 官方登录缓存"
        } else if let url = profile.baseURL {
            statusMessage = "Base URL：\(url.absoluteString)"
        }
    }

    var selectedProfile: CodexProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    private func makeUniqueID(from name: String) -> String {
        let base = name
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fallback = base.isEmpty ? "profile" : base
        let existing = Set(profiles.map(\.id))
        if !existing.contains(fallback) {
            return fallback
        }
        for index in 2...999 {
            let candidate = "\(fallback)-\(index)"
            if !existing.contains(candidate) {
                return candidate
            }
        }
        return "\(fallback)-\(UUID().uuidString.prefix(8))"
    }
}

struct ProfileDraft: Identifiable {
    var id = ""
    var name = ""
    var baseURL = ""
    var token = ""
    var iconName = "sparkle"

    init() {}

    init(profile: CodexProfile) {
        id = profile.id
        name = profile.name
        baseURL = profile.baseURL?.absoluteString ?? ""
        iconName = profile.iconName
    }
}

enum AppDirectories {
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ChatGPT-switch")
    }
}

private struct MissingCodexCLI: CodexCLI {
    func loginWithAPIKey(_ apiKey: String, codexHome: URL) throws {
        throw CodexCLIError.executableNotFound
    }

    func loginStatus(codexHome: URL) throws -> String {
        throw CodexCLIError.executableNotFound
    }
}
