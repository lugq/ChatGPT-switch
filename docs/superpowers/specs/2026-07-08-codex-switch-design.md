# ChatGPT-switch Design

## Goal

Build a native macOS SwiftUI app named `ChatGPT-switch` that switches Codex accounts in a `cc-switch`-style profile list while preserving Codex local history.

## Scope

The first version supports two profile types:

- `default`: the user's current ChatGPT/Codex official login cache.
- `base_url + token`: an OpenAI-compatible endpoint profile, for example `https://hk.rootflowai.com/v1` plus an API token.

The app must never delete or rewrite Codex history directories:

- `~/.codex/sessions`
- `~/.codex/archived_sessions`
- `~/.codex/history.jsonl`

## User Experience

The main window is a SwiftUI list modeled after the provided CC Switch screenshot:

- Title: `ChatGPT-switch`
- A profile list with large rounded rows.
- `default` appears as the user's official account and displays `未配置官网地址`.
- Custom profiles display their configured base URL.
- Current profile is highlighted with a blue border and light blue background.
- A plus button opens an add-profile sheet.
- Row actions cover use, edit, duplicate, test, and delete. The first version can expose only the actions that are implemented, but the layout should leave room for the rest.

## Switching Behavior

Switching to `default`:

1. Backup current `~/.codex/auth.json` and `~/.codex/config.toml`.
2. Save the outgoing current profile state when needed.
3. Restore the saved ChatGPT `auth.json` snapshot.
4. Remove `openai_base_url` from `~/.codex/config.toml`.
5. Ensure `cli_auth_credentials_store = "file"` exists so Codex uses `auth.json`.

Switching to a custom profile:

1. Backup current `~/.codex/auth.json` and `~/.codex/config.toml`.
2. Save the outgoing default ChatGPT snapshot when the active profile is `default`.
3. Write `openai_base_url = "<profile base URL>"` into `~/.codex/config.toml`.
4. Ensure `cli_auth_credentials_store = "file"` exists.
5. Run `codex login --with-api-key` with the token passed through stdin, never through command-line arguments.
6. Mark the profile current only after all writes succeed.
7. Roll back files if any step fails.

## Storage

App-owned data lives under:

```text
~/Library/Application Support/ChatGPT-switch/
  profiles.json
  backups/
```

Secrets are stored in macOS Keychain:

- API tokens for custom profiles.
- The `default` ChatGPT `auth.json` snapshot.

Tests use an in-memory secret store and temporary directories.

## Safety

- Token values are never printed to logs or command arguments.
- UI only shows masked token tails.
- File updates use atomic writes where possible.
- Backups are timestamped.
- Rollback restores the pre-switch auth/config files if switching fails.

## Verification

Unit tests cover:

- Default profile creation.
- Config editor setting and removing `openai_base_url`.
- Auth JSON generation through a fake CLI runner contract.
- Switch service does not touch history paths.
- Switch service rolls back auth/config on failure.

Manual verification covers:

- `swift test`
- macOS app build
- Open the app bundle
