#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "=========================================="
echo "  🎬 Finch macOS Widget v0.0.7 Derleniyor...  "
echo "  🛠️  Xcode: $(xcodebuild -version | head -n 1)"
echo "=========================================="

# 1. Swift Ana Paket Derleme (Release)
echo "📦 1. Ana uygulama derleniyor (Release)..."
swift build -c release

BIN_PATH="$DIR/.build/release/YouTubeWidget"
APP_DIR="$DIR/Finch.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLUGINS_DIR="$CONTENTS_DIR/PlugIns"

# 2. .app paket yapısı oluşturma
echo "🛠️  2. Finch.app yapısı hazırlanıyor..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$PLUGINS_DIR"

# İkili dosyayı kopyala
cp "$BIN_PATH" "$MACOS_DIR/YouTubeWidget"
chmod +x "$MACOS_DIR/YouTubeWidget"

# İkon ve AssetCatalog kontrolü ve kopyalama
if [ ! -f "$DIR/AppIcon.icns" ] || [ ! -f "$DIR/Assets.car" ]; then
    echo "🎨 Uygulama ikonu ve AssetCatalog oluşturuluyor..."
    python3 "$DIR/scripts/generate_icon.py"
fi
cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$DIR/Assets.car" "$RESOURCES_DIR/Assets.car"

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
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ufukcelen.finch</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Finch</string>
    <key>CFBundleDisplayName</key>
    <string>Finch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.7</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>7</string>
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
            <string>com.ufukcelen.finch</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>finch</string>
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
mkdir -p "$EXTENSION_DIR/Contents/Resources"
cp "$DIR/AppIcon.icns" "$EXTENSION_DIR/Contents/Resources/AppIcon.icns"
cp "$DIR/Assets.car" "$EXTENSION_DIR/Contents/Resources/Assets.car"

# 5. Ad-hoc Kod İmzalama (Doğru hiyerarşiyle ve runtime options ile)
echo "🔏 4. Kod imzalanıyor (App Sandbox & Runtime yetkileri)..."
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/extension.entitlements" "$EXTENSION_DIR" 2>/dev/null || true
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/app.entitlements" "$MACOS_DIR/YouTubeWidget" 2>/dev/null || true
codesign --force --options runtime --sign - "$APP_DIR" 2>/dev/null || true

# 6. /Applications dizinine senkronizasyon & LaunchServices kaydı
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "🚀 5. /Applications dizinine senkronize ediliyor..."
rm -rf "/Applications/YouTubeWidget.app"
rm -rf "/Applications/Finch.app"
cp -R "$APP_DIR" /Applications/

# /Applications altındaki imzayı tazele
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/extension.entitlements" "/Applications/Finch.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
codesign --force --options runtime --sign - --entitlements "$DIR/scripts/app.entitlements" "/Applications/Finch.app/Contents/MacOS/YouTubeWidget" 2>/dev/null || true
codesign --force --options runtime --sign - "/Applications/Finch.app" 2>/dev/null || true

# macOS LaunchServices & PluginKit sistem kaydı
if [ -f "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$DIR/YouTubeWidget.app" 2>/dev/null || true
    "$LSREGISTER" -u "/Applications/YouTubeWidget.app" 2>/dev/null || true
    "$LSREGISTER" -u "$DIR/Finch.app" 2>/dev/null || true
    "$LSREGISTER" -f -R -trusted /Applications/Finch.app 2>/dev/null || true
fi
pluginkit -r "$DIR/YouTubeWidget.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
pluginkit -r "/Applications/YouTubeWidget.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
pluginkit -r "$DIR/Finch.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
pluginkit -a "/Applications/Finch.app/Contents/PlugIns/YouTubeWidgetExtension.appex" 2>/dev/null || true
pluginkit -e use -i com.ufukcelen.finch.extension 2>/dev/null || true

# Simge & dock & widget önbelleklerini temizle ve zaman damgalarını güncelle
touch /Applications/Finch.app
touch /Applications/Finch.app/Contents/PlugIns/YouTubeWidgetExtension.appex
rm -rf /private/var/folders/*/*/*/com.apple.iconservices* 2>/dev/null || true
rm -rf /private/var/folders/*/*/*/com.apple.dock.iconcache 2>/dev/null || true

# chronod, NotificationCenter ve Dock (Widget Galerisi) servislerini yenile
killall -9 chronod 2>/dev/null || true
killall -9 NotificationCenter 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "=========================================="
echo "✅ Tamamlandı! Finch v0.0.7 başarıyla kuruldu:"
echo "   📍 /Applications/Finch.app"
echo "   🧩 WidgetKit Uzantısı: Aktif (3 Platform: YouTube, Instagram, TikTok - Küçük & Orta)"
echo "   🔄 Anlık Yenileme Butonu: Aktif (Masaüstünden tek tıkla canlı güncelleme)"
echo "=========================================="

if [[ "$*" == *"--run"* ]]; then
    echo "▶️  Uygulama başlatılıyor..."
    killall YouTubeWidget 2>/dev/null || true
    sleep 0.5
    open "/Applications/Finch.app"
fi
