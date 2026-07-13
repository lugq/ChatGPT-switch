import SwiftUI
import CodexSwitchCore

@main
struct CodexSwitchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: AppViewModel.production())
                .frame(minWidth: 920, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

