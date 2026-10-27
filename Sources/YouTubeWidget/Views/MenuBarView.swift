import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var viewModel: WidgetViewModel

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack {
            // Social Accounts Summary
            let y1 = viewModel.accounts["youtube1"]
            if let y1 = y1, y1.isConfigured {
                Text("🔴 YouTube (1): \(y1.title) (\(y1.mainStatCount))")
                    .font(.headline)
            } else {
                Text("🔴 YouTube Widget (Kanal Ayarlanmadı)")
                    .font(.headline)
            }

            if let y2 = viewModel.accounts["youtube2"], y2.isConfigured {
                Text("🔴 YouTube (2): \(y2.title) (\(y2.mainStatCount))")
                    .font(.caption)
            }

            if let ig = viewModel.accounts["instagram"], ig.isConfigured {
                Text("📸 Instagram: \(ig.title) (\(ig.mainStatCount) Takipçi)")
                    .font(.caption)
            }

            if let tt = viewModel.accounts["tiktok"], tt.isConfigured {
                Text("🎵 TikTok: \(tt.title) (\(tt.mainStatCount) Takipçi)")
                    .font(.caption)
            }

            Divider()

            // Quick Links
            if let y1 = y1, y1.isConfigured {
                Button("YouTube Kanalını Aç") {
                    viewModel.openChannel()
                }

                if y1.contentURL != nil {
                    Button("Son Shorts Videosunu Aç") {
                        viewModel.openLatestShort()
                    }
                }
                Divider()
            }

            // Refresh All
            Button("Tümünü Şimdi Yenile") {
                Task {
                    await viewModel.refreshAll()
                }
            }

            Divider()

            // Quit
            Button("Çıkış Yap") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
