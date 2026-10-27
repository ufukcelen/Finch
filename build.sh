#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "=========================================="
echo "  🎬 YouTube macOS Widget v0.0.6 Derleniyor...  "
echo "  🛠️  Xcode: $(xcodebuild -version | head -n 1)"
echo "=========================================="

# 1. Swift Ana Paket Derleme (Release)
echo "📦 1. Ana uygulama derleniyor (Release)..."
swift build -c release

BIN_PATH="$DIR/.build/release/YouTubeWidget"
APP_DIR="$DIR/YouTubeWidget.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLUGINS_DIR="$CONTENTS_DIR/PlugIns"

# 2. .app paket yapısı oluşturma
echo "🛠️  2. YouTubeWidget.app yapısı hazırlanıyor..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$PLUGINS_DIR"

# İkili dosyayı kopyala
cp "$BIN_PATH" "$MACOS_DIR/YouTubeWidget"
chmod +x "$MACOS_DIR/YouTubeWidget"

# İkon kontrolü ve kopyalama
if [ ! -f "$DIR/AppIcon.icns" ]; then
    echo "🎨 Uygulama ikonu oluşturuluyor..."
    python3 "$DIR/scripts/generate_icon.py"
fi
cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# 3. Ana Uygulama Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleExecutable</key>
    <string>YouTubeWidget</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ufukcelen.youtubewidget</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>YouTube Widget</string>
    <key>CFBundleDisplayName</key>
    <string>YouTube Widget</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.6</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>6</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.ufukcelen.youtubewidget</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>youtubewidget</string>
                <string>socialwidget</string>
            </array>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# 4. Xcode Projesi & AppIntents Metadata ile Yerel WidgetKit Uzantısı (.appex) Derleme
echo "🧩 3. macOS WidgetKit Uzantısı derleniyor (Xcode & AppIntents Metadata)..."
python3 "$DIR/scripts/generate_project.py"

xcodebuild -project "$DIR/YouTubeWidget.xcodeproj" \
    -target YouTubeWidgetExtension \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    -quiet

EXTENSION_DIR="$PLUGINS_DIR/YouTubeWidgetExtension.appex"
rm -rf "$EXTENSION_DIR"
cp -R "$DIR/build/Release/YouTubeWidgetExtension.appex" "$EXTENSION_DIR"

# 5. Ad-hoc Kod İmzalama (Doğru hiyerarşiyle ve runtime options ile)
echo "🔏 4. Kod imzalanıyor (App Sandbox & Runtime yetkileri)..."
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/extension.entitlements" "$EXTENSION_DIR" 2>/dev/null || true
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/app.entitlements" "$MACOS_DIR/YouTubeWidget" 2>/dev/null || true
codesign --force --options runtime --sign - "$APP_DIR" 2>/dev/null || true

# 6. /Applications dizinine senkronizasyon & LaunchServices kaydı
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "🚀 5. /Applications dizinine senkronize ediliyor..."
rm -rf "/Applications/YouTubeWidget.app"
cp -R "$APP_DIR" /Applications/

# /Applications altındaki imzayı tazele
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/extension.entitlements" "/Applications/YouTubeWidget.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/app.entitlements" "/Applications/YouTubeWidget.app/Contents/MacOS/YouTubeWidget" 2>/dev/null || true
codesign --force --options runtime --sign - "/Applications/YouTubeWidget.app" 2>/dev/null || true

# macOS LaunchServices & PluginKit sistem kaydı
if [ -f "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$DIR/YouTubeWidget.app" 2>/dev/null || true
    "$LSREGISTER" -f -R -trusted /Applications/YouTubeWidget.app 2>/dev/null || true
fi
pluginkit -r "$DIR/YouTubeWidget.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
pluginkit -a "/Applications/YouTubeWidget.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
pluginkit -e use -i com.ufukcelen.youtubewidget.extension 2>/dev/null || true

# chronod ve NotificationCenter (Widget Galerisi) servislerini yenile
killall -9 chronod 2>/dev/null || true
killall NotificationCenter 2>/dev/null || true

echo "=========================================="
echo "✅ Tamamlandı! YouTubeWidget v0.0.6 başarıyla kuruldu:"
echo "   📍 /Applications/YouTubeWidget.app"
echo "   🧩 WidgetKit Uzantısı: Aktif (3 Platform: YouTube, Instagram, TikTok - Küçük & Orta)"
echo "   ✨ Bağımsız Düzenleme: AppIntentConfiguration (Sağ tıkla kanal, tema & sıklık ayarı)"
echo "=========================================="

if [[ "$*" == *"--run"* ]]; then
    echo "▶️  Uygulama başlatılıyor..."
    killall YouTubeWidget 2>/dev/null || true
    sleep 0.5
    open "/Applications/YouTubeWidget.app"
fi
