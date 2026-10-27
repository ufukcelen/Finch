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
        // Set accessory activation policy so app lives cleanly in menu bar and desktop without dock clutter
        NSApp.setActivationPolicy(.accessory)

        // Initialize Desktop Widget
        Task { @MainActor in
            DesktopWindowManager.shared.setupDesktopWidget()

            // Open settings on first run if no channel configured yet
            if WidgetViewModel.shared.channelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DesktopWindowManager.shared.openSettingsWindow()
            }
        }
    }
}
