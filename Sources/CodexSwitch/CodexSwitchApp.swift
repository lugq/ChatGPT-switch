import AppKit
import SwiftUI
import CodexSwitchCore

@main
struct CodexSwitchApp: App {
    @StateObject private var viewModel = AppViewModel.production()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 920, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            Text("当前配置：\(viewModel.currentProfileName)")

            Divider()

            ForEach(viewModel.profiles) { profile in
                Button {
                    viewModel.switchToProfile(id: profile.id)
                } label: {
                    if profile.id == viewModel.currentProfileID {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
                .disabled(viewModel.isBusy || profile.id == viewModel.currentProfileID)
            }

            Divider()

            Button("刷新配置") {
                viewModel.load()
            }
        } label: {
            Image(nsImage: menuBarIcon)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 74, height: 18)
                .help("当前配置：\(viewModel.currentProfileName)")
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarIcon: NSImage {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApplication.shared.applicationIconImage
    }
}
