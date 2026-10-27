import SwiftUI

final class SettingsTesterState: ObservableObject {
    @Published var selectedPlatform: SocialPlatform = .youtube
    @Published var inputHandle: String = "@barisozcan"
    @Published var inputApiKey: String = ""
    @Published var isTesting: Bool = false
    @Published var testResult: String? = nil
    @Published var isSuccess: Bool = false
}

public struct SettingsView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @StateObject private var state = SettingsTesterState()

    public init(viewModel: WidgetViewModel) {
        self.viewModel = viewModel
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
                        .frame(width: 40, height: 40)

                    Image(systemName: state.selectedPlatform.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sosyal Medya Widget Yöneticisi")
                        .font(.headline)
                    Text("Masaüstü widget'larınız için hesap test edin ve doğrulayın.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("v0.0.3")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .padding()
            .background(Color.primary.opacity(0.04))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // How-To Card
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Masaüstünde Her Widget'a Özel Ayar:")
                                .font(.system(size: 12, weight: .bold))
                            Text("Masaüstünüze eklediğiniz her widget'a sağ tıklayıp **'Widget'ı Düzenle...'** seçeneğini seçerek o widget'a özel platformu (YouTube, Instagram, TikTok), kanalı ve 2-6-12-24 saatlik yenileme süresini ayrı ayrı belirleyebilirsiniz.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.08))
                    )

                    // Platform Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hesap Test Et / Doğrula:")
                            .font(.system(size: 12, weight: .bold))

                        Picker("", selection: $state.selectedPlatform) {
                            Text("🔴 YouTube").tag(SocialPlatform.youtube)
                            Text("📸 Instagram").tag(SocialPlatform.instagram)
                            Text("🎵 TikTok").tag(SocialPlatform.tiktok)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: state.selectedPlatform) { newPlat in
                            switch newPlat {
                            case .youtube: state.inputHandle = "@barisozcan"
                            case .instagram: state.inputHandle = "@instagram"
                            case .tiktok: state.inputHandle = "@tiktok"
                            }
                            state.testResult = nil
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
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.03))
                    )

                    // YouTube API Key (Optional)
                    if state.selectedPlatform == .youtube {
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
                Button("Örnek Doldur") {
                    switch state.selectedPlatform {
                    case .youtube: state.inputHandle = "@barisozcan"
                    case .instagram: state.inputHandle = "@instagram"
                    case .tiktok: state.inputHandle = "@tiktok"
                    }
                    testConnection()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Spacer()

                Button("Kapat") {
                    DesktopWindowManager.shared.closeSettingsWindow()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 480, height: 490)
    }

    private var headerColors: [Color] {
        switch state.selectedPlatform {
        case .youtube:
            return [Color(red: 1.0, green: 0.1, blue: 0.1), Color(red: 0.8, green: 0.0, blue: 0.0)]
        case .instagram:
            return [Color(red: 0.88, green: 0.19, blue: 0.42), Color(red: 0.51, green: 0.15, blue: 0.82)]
        case .tiktok:
            return [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.3)]
        }
    }

    private var inputPlaceholder: String {
        switch state.selectedPlatform {
        case .youtube: return "Örn: @barisozcan veya kanal linki"
        case .instagram: return "Örn: @instagram veya @barisozcan"
        case .tiktok: return "Örn: @tiktok"
        }
    }

    private var inputDescription: String {
        switch state.selectedPlatform {
        case .youtube: return "YouTube kullanıcı adınızı (@kullanici), kanal URL'nizi veya Kanal ID'nizi yazabilirsiniz."
        case .instagram: return "Instagram kullanıcı adınızı (@kullanici) girin. Profilinizin açık olması yeterlidir."
        case .tiktok: return "TikTok kullanıcı adınızı (@kullanici) girin. Herhangi bir şifre gerekmez."
        }
    }

    private func testConnection() {
        let clean = state.inputHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        state.isTesting = true
        state.testResult = nil

        let plat = state.selectedPlatform
        let key = state.inputApiKey.isEmpty ? nil : state.inputApiKey

        Task {
            do {
                let stats = try await SocialService.shared.fetchStats(
                    slotID: "test",
                    platform: plat,
                    input: clean,
                    apiKey: key,
                    theme: "red"
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
}
