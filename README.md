# 🎬 YouTube macOS Widget

macOS için geliştirilmiş, **YouTube Kanal İsminizi**, **Abone Sayınızı** ve **Son Eklediğiniz Shorts Videosunun İzlenme Sayısını** canlı olarak masaüstünüzde ve üst menü çubuğunuzda gösteren modern ve şık bir widget uygulaması.

---

## ✨ Özellikler

- **🔴 Canlı Kanal Bilgileri:**
  - YouTube Kanal Adı ve Özel URL (`@kullaniciadi`)
  - Kanal Profil Fotoğrafı (Avatar)
  - Güncel **Abone Sayısı** (Canlı nabız efektiyle)
- **🔥 Son Shorts (Kısa Video) Kartı:**
  - En son yüklediğiniz Shorts videosunun başlığı
  - Canlı **İzlenme Sayısı** (Görüntüleme)
  - Video önizleme görseli (Thumbnail)
  - Karta tıklandığında videoyu doğrudan tarayıcıda açma
- **🪟 Masaüstü Yüzen Widget (Desktop Floating Widget):**
  - macOS Sonoma / Sequoia tasarım diliyle uyumlu saydam cam efekti (*Frosted Glass / Ultra Thin Material*)
  - Masaüstünde istenilen konuma serbestçe sürüklenebilir (konum otomatik hatırlanır)
  - **Pencerelerin Altına Sabitleme** (gerçek masaüstü widget'ı gibi duvar kağıdı üzerinde kalma) veya **Her Zaman Üstte Tutma** seçeneği
  - Ayarlanabilir saydamlık (Opaklık ayarı)
- **🔝 Üst Menü Çubuğu (Menu Bar) Entegrasyonu:**
  - macOS üst barında YouTube simgesi ve canlı abone sayısı
  - Tek tıkla widget'ı gizleme/gösterme, anlık yenileme ve kanala gitme kısayolları
- **⚡ API Anahtarı Zorunluluğu Yoktur:**
  - Herhangi bir Google Cloud projesi veya API anahtarı oluşturmanıza gerek kalmadan, doğrudan kanal kullanıcı adınızla çalışır.
  - İsteğe bağlı olarak kendi YouTube Data API v3 anahtarınızı da kullanabilirsiniz.
- **⏱️ Otomatik Yenileme:**
  - Arka planda belirlediğiniz aralıklarla (5 dk, 15 dk, 30 dk, 1 saat) verileri otomatik günceller.

---

## 🚀 Hızlı Başlangıç

### 1. Uygulamayı Başlatma
Hazır derlenmiş `YouTubeWidget.app` uygulamasını doğrudan çalıştırabilirsiniz:

```bash
# Terminalden başlatmak için:
./build.sh --run

# veya doğrudan Finder'dan YouTubeWidget.app dosyasına çift tıklayabilirsiniz.
```

### 2. Uygulamalar Klasörüne Yükleme
Uygulamayı Mac'inizin `/Applications` klasörüne taşımak isterseniz:

```bash
./build.sh --install
```

---

## ⚙️ Yapılandırma ve Kanalınızı Bağlama

1. Uygulama ilk açıldığında veya menü çubuğundaki **YouTube simgesi -> Ayarlar...** menüsüne tıkladığınızda ayarlar penceresi açılır.
2. **YouTube Kanalınız** alanına kanal kullanıcı adınızı girin:
   - Örnek: `@kanal_adiniz`
   - veya tam link: `https://www.youtube.com/@kanal_adiniz`
   - veya Kanal ID: `UCxxxxxxxxxxxxxxxxxxxxxx`
3. **Test Et** butonuna tıklayarak kanalınızın başarıyla bağlandığını ve son Shorts videonuzun çekildiğini doğrulayın.
4. **Kaydet & Uygula** butonuna bastığınızda widget masaüstünüzde kanalınızın verileriyle canlanacaktır!

---

## 🛠️ Proje Mimarisi (Swift & SwiftUI)

```
Widged App/
├── Package.swift                             # Swift Package Manager yapılandırması
├── build.sh                                  # Tek tıkla derleme ve .app paketleme betiği
├── YouTubeWidget.app/                        # Kullanıma hazır macOS uygulaması
├── scripts/
│   └── generate_icon.py                     # 1024x1024 yüksek çözünürlüklü .icns üreteci
└── Sources/
    └── YouTubeWidget/
        ├── YouTubeWidget.swift               # @main uygulama girişi ve AppDelegate
        ├── Models/
        │   └── YouTubeStats.swift           # İstatistik ve veri modelleri
        ├── Services/
        │   └── YouTubeService.swift         # YouTube veri çekme motoru
        ├── ViewModels/
        │   └── WidgetViewModel.swift        # Durum yönetimi ve UserDefaults entegrasyonu
        ├── Windows/
        │   └── DesktopWindowManager.swift   # Saydam NSPanel ve pencere yönetimi
        └── Views/
            ├── DesktopWidgetView.swift      # Sonoma tarzı masaüstü widget tasarımı
            ├── MenuBarView.swift            # Menü çubuğu hızlı erişim menüsü
            └── SettingsView.swift           # Kanal ve widget ayar arayüzü
```

---

## 🔄 Yeniden Derleme

Kodlarda değişiklik yaptıktan sonra yeni bir sürüm derlemek için:

```bash
./build.sh
```
