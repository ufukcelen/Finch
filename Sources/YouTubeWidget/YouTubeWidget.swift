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

                if !viewModel.stats.subscriberCount.isEmpty && viewModel.stats.subscriberCount != "--" {
                    Text(displaySubCount(viewModel.stats.subscriberCount))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    private func displaySubCount(_ full: String) -> String {
        let parts = full.split(separator: " ")
        if let first = parts.first {
            return String(first)
        }
        return full
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Open settings on first run if no channel configured yet
        Task { @MainActor in
            if WidgetViewModel.shared.channelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DesktopWindowManager.shared.openSettingsWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            DesktopWindowManager.shared.openSettingsWindow()
        }
        return true
    }
}
