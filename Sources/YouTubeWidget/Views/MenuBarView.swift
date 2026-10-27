import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var viewModel: WidgetViewModel

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack {
            // Channel Info
            if viewModel.stats.isConfigured {
                Text("\(viewModel.stats.channelTitle) (\(viewModel.stats.handle))")
                    .font(.headline)
                
                Text("👥 Abone Sayısı: \(viewModel.stats.subscriberCount)")
                
                if !viewModel.stats.latestShortTitle.isEmpty {
                    Text("🎬 Son Shorts: \(viewModel.stats.latestShortTitle)")
                    Text("🔥 İzlenme: \(viewModel.stats.latestShortViews)")
                }
            } else {
                Text("YouTube Widget (Henüz Kanal Girilmedi)")
            }

            Divider()

            // Desktop Widget Visibility Toggle
            Button(viewModel.showDesktopWidget ? "Masaüstü Widget'ını Gizle" : "Masaüstü Widget'ını Göster") {
                viewModel.showDesktopWidget.toggle()
            }

            // Quick Links
            Button("YouTube'da Kanalı Aç") {
                viewModel.openChannel()
            }

            if viewModel.stats.latestShortURL != nil {
                Button("Son Shorts Videosunu Aç") {
                    viewModel.openLatestShort()
                }
            }

            Divider()

            // Refresh & Settings
            Button("Şimdi Yenile") {
                Task {
                    await viewModel.refresh()
                }
            }

            Button("Ayarlar...") {
                DesktopWindowManager.shared.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button("Çıkış Yap") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
