import Foundation

public enum ProfileKind: String, Codable, Equatable, CaseIterable {
    case chatGPTDefault
    case openAICompatible
}

public struct CodexProfile: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var kind: ProfileKind
    public var baseURL: URL?
    public var iconName: String

    public init(
        id: String,
        name: String,
        kind: ProfileKind,
        baseURL: URL?,
        iconName: String
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURL = baseURL
        self.iconName = iconName
    }

    public static func defaultProfile() -> CodexProfile {
        CodexProfile(
            id: "default",
            name: "default",
            kind: .chatGPTDefault,
            baseURL: nil,
            iconName: "d.circle"
        )
    }

    public var displaySubtitle: String {
        switch kind {
        case .chatGPTDefault:
            return "未配置官网地址"
        case .openAICompatible:
            return baseURL?.absoluteString ?? "未配置 Base URL"
        }
    }

    public var secretKey: String {
        switch kind {
        case .chatGPTDefault:
            return "profile.default.auth-json"
        case .openAICompatible:
            return "profile.\(id).api-token"
        }
    }
}

