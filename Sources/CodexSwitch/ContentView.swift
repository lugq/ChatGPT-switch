import SwiftUI
import CodexSwitchCore

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            profileList
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $viewModel.editorDraft) { draft in
            ProfileEditorView(
                draft: draft,
                onCancel: { viewModel.editorDraft = nil },
                onSave: { viewModel.saveDraft($0) }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Text("ChatGPT-switch")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.blue)

            Button(action: viewModel.load) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.secondary)
            .help("刷新配置")

            Spacer()

            HStack(spacing: 10) {
                ToolbarIcon(systemName: "wrench.and.screwdriver", help: "测试", action: viewModel.testSelectedProfile)
                ToolbarIcon(systemName: "rectangle.on.rectangle", help: "复制", action: viewModel.duplicateSelectedProfile)
                ToolbarIcon(systemName: "clock.arrow.circlepath", help: "刷新", action: viewModel.load)
                ToolbarIcon(systemName: "trash", help: "删除", action: viewModel.deleteSelectedProfile)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.6), in: Capsule())

            Button(action: viewModel.beginAddProfile) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.orange, in: Circle())
                    .shadow(color: .orange.opacity(0.28), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .help("添加 profile")
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 34)
    }

    private var profileList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(viewModel.profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        isSelected: viewModel.selectedProfileID == profile.id,
                        isCurrent: viewModel.currentProfileID == profile.id,
                        isBusy: viewModel.isBusy,
                        onSelect: { viewModel.selectedProfileID = profile.id },
                        onUse: {
                            viewModel.selectedProfileID = profile.id
                            viewModel.switchToSelectedProfile()
                        },
                        onEdit: {
                            viewModel.selectedProfileID = profile.id
                            viewModel.beginEditSelectedProfile()
                        },
                        onCopy: {
                            viewModel.selectedProfileID = profile.id
                            viewModel.duplicateSelectedProfile()
                        },
                        onTest: {
                            viewModel.selectedProfileID = profile.id
                            viewModel.testSelectedProfile()
                        },
                        onDelete: {
                            viewModel.selectedProfileID = profile.id
                            viewModel.deleteSelectedProfile()
                        }
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private var footer: some View {
        HStack {
            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("不会修改 ~/.codex/sessions")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ProfileRow: View {
    let profile: CodexProfile
    let isSelected: Bool
    let isCurrent: Bool
    let isBusy: Bool
    let onSelect: () -> Void
    let onUse: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onTest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            rowContent
            .padding(.horizontal, 22)
            .frame(minHeight: 116)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(rowBorder)
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 18) {
            Image(systemName: "circle.grid.2x3.fill")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)

            avatar
            titleBlock
            Spacer()
            rowActions
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(profile.name)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.primary)
                if isCurrent {
                    Text("使用中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }
            Text(profile.displaySubtitle)
                .font(.system(size: 18))
                .foregroundStyle(profile.kind == .chatGPTDefault ? Color.secondary : Color.blue)
                .lineLimit(1)
        }
    }

    private var rowActions: some View {
        HStack(spacing: 18) {
            RowIcon(systemName: "checkmark", help: "使用", action: onUse)
            RowIcon(systemName: "square.and.pencil", help: "编辑", action: onEdit, disabled: profile.kind == .chatGPTDefault)
            RowIcon(systemName: "doc.on.doc", help: "复制", action: onCopy, disabled: profile.kind == .chatGPTDefault)
            RowIcon(systemName: "waveform.path.ecg", help: "测试", action: onTest)
            RowIcon(systemName: "trash", help: "删除", action: onDelete, disabled: profile.kind == .chatGPTDefault || isBusy)
        }
        .opacity(isSelected ? 1 : 0.15)
    }

    private var rowBackground: some ShapeStyle {
        isSelected ? Color.blue.opacity(0.08) : Color.clear
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? Color.blue.opacity(0.68) : Color.gray.opacity(0.25), lineWidth: isSelected ? 1.3 : 1)
    }

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 52, height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
            if profile.kind == .chatGPTDefault {
                Text("D")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: profile.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.purple)
            }
        }
    }
}

private struct ToolbarIcon: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct RowIcon: View {
    let systemName: String
    let help: String
    let action: () -> Void
    var disabled = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(disabled ? .tertiary : .secondary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }
}
