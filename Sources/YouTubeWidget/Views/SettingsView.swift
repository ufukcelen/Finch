import SwiftUI

public final class SettingsState: ObservableObject {
    @Published public var inputChannel: String = ""
    @Published public var inputApiKey: String = ""
    @Published public var selectedInterval: Int = 15
    @Published public var selectedTheme: String = "red"
    @Published public var isTesting: Bool = false
    @Published public var testResult: String? = nil
    @Published public var isSuccess: Bool = false

    public init() {}
}

public struct SettingsView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var state: SettingsState

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
        let s = SettingsState()
        s.inputChannel = viewModel.channelInput
        s.inputApiKey = viewModel.apiKey
        s.selectedInterval = viewModel.refreshIntervalMinutes
        s.selectedTheme = viewModel.theme
        self.state = s
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.1, blue: 0.1), Color(red: 0.8, green: 0.0, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("YouTube Widget Ayarları")
                        .font(.headline)
                    Text("İstediğiniz YouTube kanalını bağlayın ve temayı seçin.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Section 1: Channel
                    VStack(alignment: .leading, spacing: 8) {
                        Label("YouTube Kanalınız", systemImage: "person.crop.square.filled.and.at.rectangle")
                            .font(.system(size: 13, weight: .bold))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Örn: @UykusuzTosba veya @barisozcan", text: $state.inputChannel)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    testChannelConnection()
                                } label: {
                                    if state.isTesting {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 60)
                                    } else {
                                        Text("Test Et")
                                            .frame(width: 60)
                                    }
                                }
                                .disabled(state.inputChannel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isTesting)
                            }

                            Text("Kanal kullanıcı adınızı (@kullanici), kanal URL bağlantınızı veya Kanal ID'nizi yazabilirsiniz.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        // Test feedback message
                        if let res = state.testResult {
                            HStack(spacing: 6) {
                                Image(systemName: state.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(state.isSuccess ? .green : .red)
                                Text(res)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(state.isSuccess ? .green : .red)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.03))
                    )

                    // MARK: - Section 2: Widget Theme & Customization
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Widget Teması & Görünüm", systemImage: "paintbrush.fill")
                            .font(.system(size: 13, weight: .bold))

                        // Theme Selector
                        HStack {
                            Text("Widget Teması:")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Picker("", selection: $state.selectedTheme) {
                                Text("🔴 YouTube Kırmızısı").tag("red")
                                Text("⬛️ Koyu Titanyum").tag("dark")
                                Text("🪟 Buzlu Cam (Şeffaf)").tag("glass")
                                Text("🟣 Siber Mor Neon").tag("neon")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }

                        // Refresh Interval Picker
                        HStack {
                            Text("Otomatik Yenileme Sıklığı:")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Picker("", selection: $state.selectedInterval) {
                                Text("15 Dakika").tag(15)
                                Text("30 Dakika").tag(30)
                                Text("1 Saat").tag(60)
                                Text("3 Saat").tag(180)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.03))
                    )

                    // MARK: - Section 3: Optional API Key
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("AIzaSy...", text: $state.inputApiKey)
                                .textFieldStyle(.roundedBorder)

                            Text("Varsayılan olarak widget API anahtarına ihtiyaç DUYMADAN çalışır. İsteğe bağlı olarak kendi YouTube Data API v3 anahtarınızı da girebilirsiniz.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 6)
                    } label: {
                        Label("Gelişmiş: YouTube API v3 Anahtarı (İsteğe Bağlı)", systemImage: "key.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.03))
                    )
                }
                .padding()
            }

            Divider()

            // Footer actions
            HStack {
                Button("Örnek (@barisozcan)") {
                    state.inputChannel = "@barisozcan"
                    testChannelConnection()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Spacer()

                Button("İptal") {
                    DesktopWindowManager.shared.closeSettingsWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Kaydet & Uygula") {
                    saveAndApply()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 460, height: 490)
    }

    private func testChannelConnection() {
        let clean = state.inputChannel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        state.isTesting = true
        state.testResult = nil

        Task {
            do {
                let stats = try await YouTubeService.shared.fetchStats(
                    channelInput: clean,
                    apiKey: state.inputApiKey.isEmpty ? nil : state.inputApiKey
                )
                await MainActor.run {
                    self.state.isTesting = false
                    self.state.isSuccess = true
                    self.state.testResult = "Bağlandı: '\(stats.channelTitle)' (\(stats.subscriberCount)) - Shorts: '\(stats.latestShortTitle)'"
                }
            } catch {
                await MainActor.run {
                    self.state.isTesting = false
                    self.state.isSuccess = false
                    self.state.testResult = "Hata: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveAndApply() {
        viewModel.channelInput = state.inputChannel.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.apiKey = state.inputApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.refreshIntervalMinutes = state.selectedInterval
        viewModel.theme = state.selectedTheme

        Task {
            await viewModel.refresh()
        }

        DesktopWindowManager.shared.closeSettingsWindow()
    }
}
