# ChatGPT-switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app named `ChatGPT-switch` that switches Codex `default` and `base_url + token` profiles without clearing Codex history.

**Architecture:** Use a small SwiftPM macOS executable with SwiftUI for UI and focused service types for profile storage, Codex config editing, Keychain-backed secrets, CLI login, backup, and switch orchestration. Tests run against temporary directories and in-memory fakes so the real `~/.codex` is never mutated.

**Tech Stack:** Swift 6.2, SwiftUI, Security.framework, Foundation, XCTest, Swift Package Manager.

## Global Constraints

- Do not modify `~/.codex/sessions`, `~/.codex/archived_sessions`, or `~/.codex/history.jsonl`.
- Pass API tokens through stdin to `codex login --with-api-key`; never pass tokens as command-line arguments.
- Keep `default` as the ChatGPT official-login snapshot.
- Custom profiles use `base_url + token`.
- Use `cli_auth_credentials_store = "file"` when switching so Codex reads `auth.json`.
- Write app-owned data under `~/Library/Application Support/ChatGPT-switch/`.

---

### Task 1: Project Skeleton And Core Model Tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexSwitchCore/CodexProfile.swift`
- Create: `Tests/CodexSwitchCoreTests/CodexProfileTests.swift`

**Interfaces:**
- Produces: `CodexProfile`, `ProfileKind`, `CodexProfile.defaultProfile()`.

- [ ] Create SwiftPM package with `CodexSwitchCore`, `CodexSwitch`, and test targets.
- [ ] Write failing tests for default profile and custom profile metadata.
- [ ] Implement the profile models.
- [ ] Run `swift test`.

### Task 2: Profile And Secret Storage

**Files:**
- Create: `Sources/CodexSwitchCore/ProfileStore.swift`
- Create: `Sources/CodexSwitchCore/SecretStore.swift`
- Create: `Tests/CodexSwitchCoreTests/ProfileStoreTests.swift`

**Interfaces:**
- Consumes: `CodexProfile`.
- Produces: `ProfileStore`, `SecretStore`, `InMemorySecretStore`, `KeychainSecretStore`.

- [ ] Write failing tests for loading a missing profile file and persisting a custom profile without token leakage.
- [ ] Implement JSON profile storage.
- [ ] Implement an in-memory secret store for tests.
- [ ] Implement macOS Keychain storage for app runtime.
- [ ] Run `swift test`.

### Task 3: Codex State Editing

**Files:**
- Create: `Sources/CodexSwitchCore/CodexPaths.swift`
- Create: `Sources/CodexSwitchCore/CodexConfigEditor.swift`
- Create: `Sources/CodexSwitchCore/CodexCLI.swift`
- Create: `Tests/CodexSwitchCoreTests/CodexConfigEditorTests.swift`

**Interfaces:**
- Produces: `CodexPaths`, `CodexConfigEditor.apply(baseURL:)`, `CodexCLI.loginWithAPIKey(_:)`.

- [ ] Write failing tests for setting/removing `openai_base_url` while preserving unrelated TOML.
- [ ] Write failing tests for ensuring `cli_auth_credentials_store = "file"`.
- [ ] Implement config editing with line-based top-level key replacement.
- [ ] Implement CLI runner that pipes token through stdin.
- [ ] Run `swift test`.

### Task 4: Switch Orchestration And Rollback

**Files:**
- Create: `Sources/CodexSwitchCore/SwitchService.swift`
- Create: `Tests/CodexSwitchCoreTests/SwitchServiceTests.swift`

**Interfaces:**
- Consumes: `ProfileStore`, `SecretStore`, `CodexConfigEditor`, `CodexCLI`.
- Produces: `SwitchService.switchToProfile(id:)`.

- [ ] Write failing tests proving history paths are untouched.
- [ ] Write failing tests for rollback after API login failure.
- [ ] Implement backup, default snapshot capture, custom switching, current marker update, and rollback.
- [ ] Run `swift test`.

### Task 5: SwiftUI App

**Files:**
- Create: `Sources/CodexSwitch/CodexSwitchApp.swift`
- Create: `Sources/CodexSwitch/AppViewModel.swift`
- Create: `Sources/CodexSwitch/ContentView.swift`
- Create: `Sources/CodexSwitch/ProfileEditorView.swift`

**Interfaces:**
- Consumes: core services.
- Produces: a native macOS window for listing, adding, editing, deleting, and switching profiles.

- [ ] Implement app view model.
- [ ] Implement CC Switch-style list UI.
- [ ] Implement add/edit sheet for name, base URL, and token.
- [ ] Implement use/delete actions with status text.
- [ ] Run `swift test`.
- [ ] Run `swift build`.

### Task 6: App Bundle Output

**Files:**
- Create: `scripts/build_app_bundle.sh`
- Output: `outputs/ChatGPT-switch.app`

**Interfaces:**
- Consumes: SwiftPM build output.
- Produces: a macOS `.app` bundle.

- [ ] Build release executable.
- [ ] Create `ChatGPT-switch.app/Contents`.
- [ ] Write `Info.plist`.
- [ ] Copy executable into `Contents/MacOS/ChatGPT-switch`.
- [ ] Verify the bundle exists and the executable launches.
