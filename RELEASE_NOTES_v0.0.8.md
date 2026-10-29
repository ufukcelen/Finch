# 🐦 Finch — macOS Social Media Widget v0.0.8 Release

Finch (eski adıyla YouTubeWidget), macOS için özel olarak geliştirilmiş çoklu platform (YouTube, Instagram, TikTok) masaüstü ve Bildirim Merkezi araç takımı (WidgetKit) uygulamasıdır.

### 🌟 Bu Sürümdeki Yenilikler (v0.0.8):

1. **🎨 Finch Marka Dönüşümü & Yeni İkon:**
   - Uygulama adı tamamen **Finch** olarak güncellendi.
   - Yeni renkli Finch maskotu vektörel ve yüksek çözünürlüklü Retina `AppIcon.icns` ve `Assets.car` (Asset Catalog) olarak derlendi.
   - macOS Araç Takımı Galerisi (Widget Gallery) ve Bildirim Merkezi önbellek entegrasyonu `FinchExtension` olarak yenilendi.

2. **⚡️ Uygulama İçi Otomatik GitHub Güncelleme Denetleyicisi:**
   - Ayarlar penceresine doğrudan GitHub REST API ile entegre yeni sürüm kontrol mekanizması eklendi.
   - Yeni bir sürüm yayınlandığında otomatik bildirim çubuğu ("Yeni Sürüm Mevcut!") ve tek tıkla doğrudan GitHub'dan indirme desteği.
   - Manuel "Güncellemeleri Denetle" butonu ile canlı sürüm sorgulama.

3. **🔄 Canlı Zaman Damgası & Gelişmiş Yenileme Geri Bildirimi:**
   - Widget ayaklığında gerçek zamanlı `🟢 SS:dd` formatında son güncelleme saati gösterilir.
   - Widget üzerindeki interaktif 🔄 yenileme butonuna tıklandığında zaman damgası anında güncellenerek görsel geri bildirim sağlar.

4. **🗂️ Güçlendirilmiş Çoklu Sandbox Veri Senkronizasyonu:**
   - App Sandbox kısıtlamalarını aşmak için ana uygulama ile widget uzantısı arasında çoklu güvenli dosya yolu senkronizasyonu.
   - Atomik yazma ve önbellekleme ile sıfır veri kaybı.

---

### 📦 İndirme & Kurulum
1. `Finch-v0.0.8-macOS.zip` dosyasını indirin ve çift tıklayarak açın.
2. `Finch.app` dosyasını `/Applications` (Uygulamalar) klasörünüze taşıyın.
3. Uygulamayı çalıştırın. Menü çubuğundan veya masaüstünüzden dilediğiniz kanalları ekleyin.
4. Masaüstünüze veya Bildirim Merkezi'ne sağ tıklayıp "Araç Takımlarını Düzenle" diyerek **Finch** widget'larını ekleyebilirsiniz.

### 🔐 Doğrulama (Checksum)
- **Dosya:** `Finch-v0.0.8-macOS.zip`
- **SHA-256:** `29ee9fffca61d539c7da48b8b4dd91861ffdb553fd7c263118a7e4f28f707b0a`
