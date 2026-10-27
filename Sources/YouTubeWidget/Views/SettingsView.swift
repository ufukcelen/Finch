import SwiftUI

public final class SettingsState: ObservableObject {
    @Published public var activeSlot: String = "youtube1"
    @Published public var inputHandle: String = ""
    @Published public var inputApiKey: String = ""
    @Published public var selectedInterval: Int = 360
    @Published public var selectedTheme: String = "red"
    @Published public var isTesting: Bool = false
    @Published public var testResult: String? = nil
    @Published public var isSuccess: Bool = false

    public init() {}
}

public struct SettingsView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @StateObject private var state = SettingsState()

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
    }

    private var activePlatform: SocialPlatform {
        switch state.activeSlot {
        case "instagram": return .instagram
        case "tiktok": return .tiktok
        default: return .youtube
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: headerColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: activePlatform.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Widget Ayarları & Kanal Değiştir")
                        .font(.headline)
                    Text("Widget kütüphanesinden eklenen her widgeti dilediğiniz hesaba bağlayın.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.primary.opacity(0.04))

            Divider()

            // Slot Tabs (Segmented Control)
            VStack(spacing: 6) {
                HStack {
                    Text("Yapılandırılan Widget:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Picker("", selection: $state.activeSlot) {
                    Text("🔴 YouTube (1)").tag("youtube1")
                    Text("🔴 YouTube (2)").tag("youtube2")
                    Text("📸 Instagram").tag("instagram")
                    Text("🎵 TikTok").tag("tiktok")
                }
                .pickerStyle(.segmented)
                .onChange(of: state.activeSlot) { newSlot in
                    loadSlotData(newSlot)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // MARK: - Section 1: Channel / Account Input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(inputSectionTitle, systemImage: activePlatform.iconName)
                                .font(.system(size: 13, weight: .bold))
                            Spacer()
                            if let acc = viewModel.accounts[state.activeSlot], acc.isConfigured {
                                Text("Mevcut: \(acc.mainStatCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                TextField(inputPlaceholder, text: $state.inputHandle)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    testConnection()
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
                                .disabled(state.inputHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isTesting)
                            }

                            Text(inputDescription)
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
                                    .lineLimit(2)
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
                        Label("Görünüm & Tema", systemImage: "paintbrush.fill")
                            .font(.system(size: 13, weight: .bold))

                        HStack {
                            Text("Widget Teması:")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Picker("", selection: $state.selectedTheme) {
                                Text("🔴 Canlı Kırmızı").tag("red")
                                Text("⬛️ Koyu Titanyum").tag("dark")
                                Text("🪟 Buzlu Cam (Şeffaf)").tag("glass")
                                Text("🟣 Siber Mor Neon").tag("neon")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }

                        Divider()

                        // MARK: - Update Interval (2h, 6h, 12h, 24h as requested)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Otomatik Güncelleme:")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Sistemi ve pili yormamak için periyot seçin")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $state.selectedInterval) {
                                Text("2 Saat").tag(120)
                                Text("6 Saat (Önerilen)").tag(360)
                                Text("12 Saat").tag(720)
                                Text("24 Saat").tag(1440)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 160)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.03))
                    )

                    // MARK: - Section 3: Optional YouTube API Key
                    if activePlatform == .youtube {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("AIzaSy...", text: $state.inputApiKey)
                                    .textFieldStyle(.roundedBorder)

                                Text("Varsayılan olarak YouTube Data API anahtarı gerekmeden doğrudan çalışır. İsteğe bağlı olarak kendi API anahtarınızı da kullanabilirsiniz.")
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
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button(sampleButtonLabel) {
                    fillSample()
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
        .frame(width: 480, height: 530)
        .onAppear {
            state.activeSlot = viewModel.activeSlot
            loadSlotData(viewModel.activeSlot)
        }
    }

    // MARK: - UI Helpers
    private var headerColors: [Color] {
        switch activePlatform {
        case .youtube:
            return [Color(red: 1.0, green: 0.1, blue: 0.1), Color(red: 0.8, green: 0.0, blue: 0.0)]
        case .instagram:
            return [Color(red: 0.88, green: 0.19, blue: 0.42), Color(red: 0.51, green: 0.15, blue: 0.82)]
        case .tiktok:
            return [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.3)]
        }
    }

    private var inputSectionTitle: String {
        switch state.activeSlot {
        case "youtube1": return "YouTube Ana Kanalı"
        case "youtube2": return "YouTube 2. Kanalı"
        case "instagram": return "Instagram Hesabı"
        case "tiktok": return "TikTok Hesabı"
        default: return "Sosyal Medya Hesabı"
        }
    }

    private var inputPlaceholder: String {
        switch activePlatform {
        case .youtube: return "Örn: @barisozcan veya @UykusuzTosba"
        case .instagram: return "Örn: @instagram veya @barisozcan"
        case .tiktok: return "Örn: @tiktok veya @mrbeast"
        }
    }

    private var inputDescription: String {
        switch activePlatform {
        case .youtube:
            return "YouTube kullanıcı adınızı (@kullanici), kanal URL'nizi veya Kanal ID'nizi yazabilirsiniz."
        case .instagram:
            return "Instagram kullanıcı adınızı (@kullanici) girin. Profilinizin açık olması yeterlidir."
        case .tiktok:
            return "TikTok kullanıcı adınızı (@kullanici) girin. Herhangi bir şifre gerekmez."
        }
    }

    private var sampleButtonLabel: String {
        switch activePlatform {
        case .youtube: return "Örnek Doldur (@barisozcan)"
        case .instagram: return "Örnek Doldur (@instagram)"
        case .tiktok: return "Örnek Doldur (@tiktok)"
        }
    }

    private func fillSample() {
        switch activePlatform {
        case .youtube: state.inputHandle = "@barisozcan"
        case .instagram: state.inputHandle = "@instagram"
        case .tiktok: state.inputHandle = "@tiktok"
        }
        testConnection()
    }

    private func loadSlotData(_ slot: String) {
        state.testResult = nil
        state.selectedInterval = viewModel.refreshIntervalMinutes
        state.inputApiKey = viewModel.apiKey

        if let acc = viewModel.accounts[slot] {
            state.inputHandle = acc.handle.isEmpty ? acc.title : acc.handle
            state.selectedTheme = acc.theme
        } else {
            state.inputHandle = ""
            state.selectedTheme = activePlatform == .instagram ? "purple" : (activePlatform == .tiktok ? "neon" : "red")
        }
    }

    private func testConnection() {
        let clean = state.inputHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        state.isTesting = true
        state.testResult = nil

        let slot = state.activeSlot
        let plat = activePlatform
        let key = state.inputApiKey.isEmpty ? nil : state.inputApiKey
        let theme = state.selectedTheme

        Task {
            do {
                let stats = try await SocialService.shared.fetchStats(
                    slotID: slot,
                    platform: plat,
                    input: clean,
                    apiKey: key,
                    theme: theme
                )
                await MainActor.run {
                    self.state.isTesting = false
                    self.state.isSuccess = true
                    self.state.testResult = "Bağlandı: '\(stats.title)' (\(stats.mainStatCount) \(plat.statTitle.lowercased()))"
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
        let clean = state.inputHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        let slot = state.activeSlot
        let plat = activePlatform
        let theme = state.selectedTheme
        let key = state.inputApiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.refreshIntervalMinutes = state.selectedInterval
        if !key.isEmpty {
            viewModel.apiKey = key
        }

        Task {
            if !clean.isEmpty {
                try? await viewModel.saveAccount(
                    slotID: slot,
                    platform: plat,
                    input: clean,
                    theme: theme,
                    apiKey: key.isEmpty ? nil : key
                )
            } else if var acc = viewModel.accounts[slot] {
                acc.theme = theme
                viewModel.accounts[slot] = acc
                viewModel.syncToSharedData()
            }
        }

        DesktopWindowManager.shared.closeSettingsWindow()
    }
}
