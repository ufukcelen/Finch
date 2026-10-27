import SwiftUI
import WidgetKit

@MainActor
final class SettingsFormState: ObservableObject {
    @Published var selectedSlot: String = "youtube1"
    @Published var selectedPlatform: SocialPlatform = .youtube
    @Published var inputHandle: String = "@barisozcan"
    @Published var selectedTheme: String = "red"
    @Published var selectedInterval: Int = 360
    @Published var inputApiKey: String = ""

    @Published var isTesting: Bool = false
    @Published var testResult: String? = nil
    @Published var isTestSuccess: Bool = false

    @Published var isSaving: Bool = false
    @Published var saveSuccessMessage: String? = nil
    @Published var saveErrorMessage: String? = nil

    func loadSlot(_ slotID: String, viewModel: WidgetViewModel) {
        selectedSlot = slotID
        viewModel.activeSlot = slotID
        saveSuccessMessage = nil
        saveErrorMessage = nil
        testResult = nil

        if let acc = viewModel.accounts[slotID] {
            selectedPlatform = acc.platform
            inputHandle = acc.handle
            selectedTheme = acc.theme
        } else {
            switch slotID {
            case "instagram":
                selectedPlatform = .instagram
                inputHandle = "@instagram"
            case "tiktok":
                selectedPlatform = .tiktok
                inputHandle = "@tiktok"
            default:
                selectedPlatform = .youtube
                inputHandle = "@barisozcan"
            }
            selectedTheme = "red"
        }
        selectedInterval = viewModel.refreshIntervalMinutes
        inputApiKey = viewModel.apiKey
    }

    func testConnection() {
        let clean = inputHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isTesting = true
        testResult = nil

        let plat = selectedPlatform
        let key = inputApiKey.isEmpty ? nil : inputApiKey
        let slot = selectedSlot
        let th = selectedTheme

        Task {
            do {
                let stats = try await SocialService.shared.fetchStats(
                    slotID: slot,
                    platform: plat,
                    input: clean,
                    apiKey: key,
                    theme: th
                )
                await MainActor.run {
                    self.isTesting = false
                    self.isTestSuccess = true
                    self.testResult = "Bağlandı: '\(stats.title)' (\(stats.mainStatCount) \(plat.statTitle.lowercased()))"
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.isTestSuccess = false
                    self.testResult = "Hata: \(error.localizedDescription)"
                }
            }
        }
    }

    func saveCurrentSlot(viewModel: WidgetViewModel) {
        let clean = inputHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isSaving = true
        saveSuccessMessage = nil
        saveErrorMessage = nil

        let slot = selectedSlot
        let plat = selectedPlatform
        let th = selectedTheme
        let key = inputApiKey.isEmpty ? nil : inputApiKey
        let interval = selectedInterval

        viewModel.refreshIntervalMinutes = interval
        if !inputApiKey.isEmpty {
            viewModel.apiKey = inputApiKey
        }

        Task {
            do {
                try await viewModel.saveAccount(
                    slotID: slot,
                    platform: plat,
                    input: clean,
                    theme: th,
                    apiKey: key
                )
                await MainActor.run {
                    self.isSaving = false
                    self.saveSuccessMessage = "✅ '\(clean)' hesabı kaydedildi! Masaüstü widget'ı hemen güncelleniyor."
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.saveErrorMessage = "Kaydetme hatası: \(error.localizedDescription)"
                }
            }
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @StateObject private var form = SettingsFormState()

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
                        .frame(width: 42, height: 42)

                    Image(systemName: form.selectedPlatform.iconName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sosyal Medya Widget Yöneticisi")
                        .font(.system(size: 15, weight: .bold))
                    Text("Masaüstündeki her widget için bağımsız kanal ve süre belirleyin.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("v0.0.3")
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.04))

            Divider()

            // Slot Tabs (Widget 1, Widget 2, Widget 3, Widget 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("DÜZENLENECEK WIDGET'I SEÇİN:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                HStack(spacing: 8) {
                    slotButton(id: "youtube1", title: "Widget 1 (Ana)", defaultPlat: .youtube)
                    slotButton(id: "youtube2", title: "Widget 2", defaultPlat: .youtube)
                    slotButton(id: "instagram", title: "Widget 3 (Insta)", defaultPlat: .instagram)
                    slotButton(id: "tiktok", title: "Widget 4 (TikTok)", defaultPlat: .tiktok)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .background(Color.primary.opacity(0.02))

            Divider()

            // Scrollable Configuration Form
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Platform Selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Platform")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $form.selectedPlatform) {
                            Text("🔴 YouTube").tag(SocialPlatform.youtube)
                            Text("📸 Instagram").tag(SocialPlatform.instagram)
                            Text("🎵 TikTok").tag(SocialPlatform.tiktok)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: form.selectedPlatform) { _ in
                            form.testResult = nil
                        }
                    }

                    // Account Handle
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Kanal veya Kullanıcı Adı")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack {
                            TextField(inputPlaceholder, text: $form.inputHandle)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                form.testConnection()
                            } label: {
                                if form.isTesting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 70)
                                } else {
                                    Text("Test Et")
                                        .frame(width: 70)
                                }
                            }
                            .disabled(form.inputHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || form.isTesting)
                        }

                        Text(inputDescription)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    // Test Feedback
                    if let res = form.testResult {
                        HStack(spacing: 6) {
                            Image(systemName: form.isTestSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(form.isTestSuccess ? .green : .red)
                            Text(res)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(form.isTestSuccess ? .green : .red)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(form.isTestSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        )
                    }

                    // Refresh Interval (Strictly 2, 6, 12, 24 hours)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Güncelleme Sıklığı")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Sistemi yormaz")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Picker("", selection: $form.selectedInterval) {
                            Text("2 Saat").tag(120)
                            Text("6 Saat (Önerilen)").tag(360)
                            Text("12 Saat").tag(720)
                            Text("24 Saat").tag(1440)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Theme Selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Görünüm Teması")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $form.selectedTheme) {
                            Text("🔴 Canlı Kırmızı").tag("red")
                            Text("⬛️ Koyu Titanyum").tag("dark")
                            Text("🪟 Buzlu Cam").tag("glass")
                            Text("🟣 Siber Mor").tag("neon")
                        }
                        .pickerStyle(.segmented)
                    }

                    // Optional YouTube API Key
                    if form.selectedPlatform == .youtube {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("AIzaSy...", text: $form.inputApiKey)
                                    .textFieldStyle(.roundedBorder)
                                Text("İsteğe bağlıdır. API anahtarı olmadan da doğrudan profil kazıma ile çalışır.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        } label: {
                            Label("YouTube API v3 Anahtarı (İsteğe Bağlı)", systemImage: "key.fill")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                    }

                    // Save Notifications
                    if let success = form.saveSuccessMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.12)))
                    }

                    if let err = form.saveErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
                    }

                    // Primary Save & Apply Button
                    Button {
                        form.saveCurrentSlot(viewModel: viewModel)
                    } label: {
                        HStack {
                            if form.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            }
                            Text("Kaydet & Widget'a Uygula")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(form.inputHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || form.isSaving)
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Button("Örnek Doldur") {
                    switch form.selectedPlatform {
                    case .youtube: form.inputHandle = "@barisozcan"
                    case .instagram: form.inputHandle = "@instagram"
                    case .tiktok: form.inputHandle = "@tiktok"
                    }
                    form.testConnection()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Spacer()

                Button("Kapat") {
                    DesktopWindowManager.shared.closeSettingsWindow()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 540, height: 580)
        .onAppear {
            form.loadSlot(viewModel.activeSlot, viewModel: viewModel)
        }
        .onChange(of: viewModel.activeSlot) { newSlot in
            form.loadSlot(newSlot, viewModel: viewModel)
        }
    }

    // MARK: - Slot Button Builder
    @ViewBuilder
    private func slotButton(id: String, title: String, defaultPlat: SocialPlatform) -> some View {
        let isSelected = form.selectedSlot == id
        let acc = viewModel.accounts[id]
        let currentPlat = acc?.platform ?? defaultPlat

        Button {
            form.loadSlot(id, viewModel: viewModel)
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: currentPlat.iconName)
                        .font(.system(size: 10))
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                }

                Text(acc?.handle.isEmpty == false ? acc!.handle : "Ayarla")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private var headerColors: [Color] {
        switch form.selectedPlatform {
        case .youtube:
            return [Color(red: 1.0, green: 0.1, blue: 0.1), Color(red: 0.8, green: 0.0, blue: 0.0)]
        case .instagram:
            return [Color(red: 0.88, green: 0.19, blue: 0.42), Color(red: 0.51, green: 0.15, blue: 0.82)]
        case .tiktok:
            return [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.3)]
        }
    }

    private var inputPlaceholder: String {
        switch form.selectedPlatform {
        case .youtube: return "Örn: @barisozcan veya kanal linki"
        case .instagram: return "Örn: @instagram veya @barisozcan"
        case .tiktok: return "Örn: @tiktok"
        }
    }

    private var inputDescription: String {
        switch form.selectedPlatform {
        case .youtube: return "YouTube kullanıcı adı (@kullanici), kanal URL veya ID girin."
        case .instagram: return "Instagram kullanıcı adı (@kullanici) girin. Profil açık olmalıdır."
        case .tiktok: return "TikTok kullanıcı adı (@kullanici) girin. Şifre gerekmez."
        }
    }
}
