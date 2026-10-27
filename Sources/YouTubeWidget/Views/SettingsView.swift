import SwiftUI
import WidgetKit
import AppKit

@MainActor
final class SettingsFormState: ObservableObject {
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

    @Published var showDebugSheet: Bool = false

    func loadPlatform(_ platform: SocialPlatform, viewModel: WidgetViewModel) {
        selectedPlatform = platform
        saveSuccessMessage = nil
        saveErrorMessage = nil
        testResult = nil

        let key = platform.rawValue
        if let acc = viewModel.accounts[key] ?? viewModel.accounts["\(key)1"] {
            inputHandle = acc.handle
            selectedTheme = acc.theme
        } else {
            switch platform {
            case .youtube: inputHandle = "@RadioMocas"
            case .instagram: inputHandle = "@uykusuztosba"
            case .tiktok: inputHandle = "@uykusuztosba"
            }
            selectedTheme = platform == .youtube ? "red" : "neon"
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
        let th = selectedTheme

        DebugLogger.shared.log(.info, tag: "SettingsView", message: "Bağlantı testi başlatıldı: platform=\(plat.displayName), input=\(clean)")

        Task {
            do {
                let stats = try await SocialService.shared.fetchStats(
                    slotID: plat.rawValue,
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

    func saveCurrentPlatform(viewModel: WidgetViewModel) {
        let clean = inputHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isSaving = true
        saveSuccessMessage = nil
        saveErrorMessage = nil

        let plat = selectedPlatform
        let th = selectedTheme
        let key = inputApiKey.isEmpty ? nil : inputApiKey
        let interval = selectedInterval

        viewModel.refreshIntervalMinutes = interval
        if !inputApiKey.isEmpty {
            viewModel.apiKey = inputApiKey
        }

        DebugLogger.shared.log(.info, tag: "SettingsView", message: "Kaydetme başlatıldı: platform=\(plat.rawValue), handle=\(clean)")

        Task {
            do {
                try await viewModel.saveAccount(
                    slotID: plat.rawValue,
                    platform: plat,
                    input: clean,
                    theme: th,
                    apiKey: key
                )
                await MainActor.run {
                    self.isSaving = false
                    self.saveSuccessMessage = "✅ '\(clean)' hesabı kaydedildi! Masaüstü widget'ları güncelleniyor."
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
    @ObservedObject private var logger = DebugLogger.shared

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
                    Text("Masaüstündeki her widget bağımsız çalışır ve sağ tıklanarak düzenlenebilir.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    form.showDebugSheet.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ladybug.fill")
                        Text("Hata Ayıklama")
                    }
                    .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("v0.0.6")
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.04))

            Divider()

            // Platform Tabs (YouTube, Instagram, TikTok)
            VStack(alignment: .leading, spacing: 6) {
                Text("VARSAYILAN HESAP & TEST PLATFORMU:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    platformTabButton(platform: .youtube, title: "YouTube")
                    platformTabButton(platform: .instagram, title: "Instagram")
                    platformTabButton(platform: .tiktok, title: "TikTok")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .background(Color.primary.opacity(0.02))

            Divider()

            // Scrollable Configuration Form
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Desktop Widget Guide Card
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bağımsız Masaüstü Düzenleme (Sağ Tık)")
                                .font(.system(size: 12, weight: .bold))

                            Text("Masaüstündeki herhangi bir widget'a **sağ tıklayıp 'Araç Takımını Düzenle'** diyerek o widget'ın kanalını, temasını ve güncelleme sıklığını diğerlerinden tamamen bağımsız olarak belirleyebilirsiniz.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.08))
                    )

                    // Account Handle
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(form.selectedPlatform.displayName) Kanalı veya Kullanıcı Adı")
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

                    // Refresh Interval
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
                        form.saveCurrentPlatform(viewModel: viewModel)
                    } label: {
                        HStack {
                            if form.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            }
                            Text("Kaydet & Masaüstüne Uygula")
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
                    case .youtube: form.inputHandle = "@RadioMocas"
                    case .instagram: form.inputHandle = "@uykusuztosba"
                    case .tiktok: form.inputHandle = "@uykusuztosba"
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
        .frame(width: 540, height: 600)
        .sheet(isPresented: $form.showDebugSheet) {
            debugSheetView
        }
        .onAppear {
            let plat: SocialPlatform
            switch viewModel.activeSlot {
            case "instagram": plat = .instagram
            case "tiktok": plat = .tiktok
            default: plat = .youtube
            }
            form.loadPlatform(plat, viewModel: viewModel)
        }
    }

    // MARK: - Platform Tab Button
    private func platformTabButton(platform: SocialPlatform, title: String) -> some View {
        let isSelected = form.selectedPlatform == platform
        let acc = viewModel.accounts[platform.rawValue] ?? viewModel.accounts["\(platform.rawValue)1"]

        return Button {
            form.loadPlatform(platform, viewModel: viewModel)
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: platform.iconName)
                        .font(.system(size: 12))
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                }

                Text(acc?.handle.isEmpty == false ? acc!.handle : "Ayarla")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debug Diagnostics Sheet View
    private var debugSheetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Hata Ayıklama & Tanı Modu", systemImage: "ladybug.fill")
                    .font(.headline)
                Spacer()
                Button("Kapat") {
                    form.showDebugSheet = false
                }
            }
            .padding(.bottom, 4)

            // Storage Diagnostic Paths
            VStack(alignment: .leading, spacing: 4) {
                Text("DEPOLAMA DOSYA DURUMU:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                ForEach(SharedDataManager.shared.getStorageDiagnostics(), id: \.path) { diag in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(diag.exists ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(diag.path)
                            .font(.system(size: 9, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(diag.exists ? "\(diag.sizeBytes) B" : "Yok")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(diag.exists ? .secondary : .red)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            // Live Log Console
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CANLI HATA AYIKLAMA LOGLARI:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Kopyala") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(logger.getRecentLogsText(), forType: .string)
                    }
                    .controlSize(.mini)

                    Button("Temizle") {
                        logger.clear()
                    }
                    .controlSize(.mini)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(logger.entries) { entry in
                            Text(entry.formattedText)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(colorForLevel(entry.level))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 220)
                .background(Color.black.opacity(0.85))
                .cornerRadius(6)
            }

            HStack {
                Button("Log Dosyasını Finder'da Göster") {
                    let logURL = logger.logFileURL
                    NSWorkspace.shared.activateFileViewerSelecting([logURL])
                }
                .font(.caption)

                Spacer()

                Button("Tüm Veriyi Zorla Yenile") {
                    Task {
                        await viewModel.refreshAll()
                    }
                }
                .font(.caption.bold())
            }
        }
        .padding(16)
        .frame(width: 580, height: 520)
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .white
        case .warning: return .yellow
        case .error: return .red
        }
    }

    // MARK: - Helpers
    private func colorFromHex(_ hex: String) -> Color {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleanHex.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 0, 0)
        }
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    private var headerColors: [Color] {
        switch form.selectedPlatform {
        case .youtube:
            return [colorFromHex("#FF0000"), colorFromHex("#8B0000")]
        case .instagram:
            return [colorFromHex("#833AB4"), colorFromHex("#FD1D1D"), colorFromHex("#FCB045")]
        case .tiktok:
            return [colorFromHex("#00F2FE"), colorFromHex("#4FACFE")]
        }
    }

    private var inputPlaceholder: String {
        switch form.selectedPlatform {
        case .youtube: return "@RadioMocas veya kanal adı"
        case .instagram: return "@uykusuztosba veya kullanıcı adı"
        case .tiktok: return "@uykusuztosba veya kullanıcı adı"
        }
    }

    private var inputDescription: String {
        switch form.selectedPlatform {
        case .youtube:
            return "YouTube kanal handle (@kanal) veya adını girin. Herhangi bir YouTube kanalı olabilir."
        case .instagram:
            return "Instagram kullanıcı adı (@kullanici) girin. Profilinizin herkese açık olması önerilir."
        case .tiktok:
            return "TikTok kullanıcı adı (@kullanici) girin. Şifre gerekmez."
        }
    }
}
