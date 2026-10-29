# 🐦 Finch — macOS Sosyal Medya Widget Yöneticisi

macOS için geliştirilmiş; **YouTube**, **Instagram** ve **TikTok** hesaplarınızın takipçi, abone ve canlı istatistiklerini masaüstünüzde şık widget'larla gösteren modern bir araç takımı uygulaması.

> 📦 **GitHub Deposu:** [https://github.com/ufukcelen/Finch](https://github.com/ufukcelen/Finch)

---

## ✨ Özellikler

- **📱 Bağımsız 3 Sosyal Medya Platformu:**
  - 🔴 **YouTube:** Abone sayısı ve son Shorts videosu
  - 🟣 **Instagram:** Takipçi ve gönderi sayısı
  - ⚫ **TikTok:** Takipçi ve toplam beğeni sayısı
- **🔄 Anlık Masaüstü Yenileme (Interactive Refresh):**
  - Masaüstündeki widget üzerinden tek tıkla canlı verileri yenileme
- **🪟 macOS Sonoma & Sequoia Yerel Widget Desteği:**
  - Hem Küçük (Small) hem de Orta (Medium) boyut seçenekleri
  - "Araç Takımını Düzenle" ile her masaüstü widget'ına özel hesap ve tema seçimi
- **⚡ API Anahtarı Zorunluluğu Yoktur:**
  - Hesap kullanıcı adınızla doğrudan çalışır; isteğe bağlı YouTube Data API v3 de desteklenir.

---

## 🚀 Hızlı Başlangıç

### Derleme & Çalıştırma
```bash
./build.sh --run
```

Derleme tamamlandığında `/Applications/Finch.app` olarak sisteme kurulur ve WidgetKit uzantısı aktif hale gelir.

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
