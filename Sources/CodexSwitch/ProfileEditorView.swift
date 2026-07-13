import SwiftUI

struct ProfileEditorView: View {
    @State private var draft: ProfileDraft
    let onCancel: () -> Void
    let onSave: (ProfileDraft) -> Void

    init(draft: ProfileDraft, onCancel: @escaping () -> Void, onSave: @escaping (ProfileDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.id.isEmpty ? "添加 Profile" : "编辑 Profile")
                .font(.title2.weight(.semibold))

            TextField("名称", text: $draft.name)
                .textFieldStyle(.roundedBorder)

            TextField("Base URL，例如 https://hk.rootflowai.com/v1", text: $draft.baseURL)
                .textFieldStyle(.roundedBorder)

            SecureField(draft.id.isEmpty ? "API Token" : "API Token（留空则不修改）", text: $draft.token)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    onSave(draft)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

