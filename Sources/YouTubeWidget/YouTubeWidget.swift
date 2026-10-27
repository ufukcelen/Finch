import SwiftUI
import AppKit

@main
struct YouTubeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var viewModel = WidgetViewModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)

                if !viewModel.primaryAccountDisplayCount.isEmpty && viewModel.primaryAccountDisplayCount != "--" {
                    Text(viewModel.primaryAccountDisplayCount)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Open settings on first run if no account is configured yet
        Task { @MainActor in
            if !WidgetViewModel.shared.hasAnyConfiguredAccount {
                DesktopWindowManager.shared.openSettingsWindow(slot: "youtube1")
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in
            handleIncomingURL(url)
        }
    }

    @MainActor
    private func handleIncomingURL(_ url: URL) {
        // e.g. youtubewidget://settings?slot=youtube1 or youtubewidget://settings?slot=instagram
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let slot = components?.queryItems?.first(where: { $0.name == "slot" })?.value ?? "youtube1"
        DesktopWindowManager.shared.openSettingsWindow(slot: slot)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            DesktopWindowManager.shared.openSettingsWindow(slot: WidgetViewModel.shared.activeSlot)
        }
        return true
    }
}
