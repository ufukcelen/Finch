#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=========================================="
echo "  🎬 YouTube macOS Widget Derleniyor...  "
echo "=========================================="

# 1. Swift derleme (Release modu)
echo "📦 Swift paketi derleniyor (Release)..."
swift build -c release

BIN_PATH="$DIR/.build/release/YouTubeWidget"
APP_DIR="$DIR/YouTubeWidget.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 2. .app paket yapısı oluşturma
echo "🛠️  YouTubeWidget.app paketi hazırlanıyor..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# İkili dosyayı kopyala
cp "$BIN_PATH" "$MACOS_DIR/YouTubeWidget"
chmod +x "$MACOS_DIR/YouTubeWidget"

# İkon kontrolü ve kopyalama
if [ ! -f "$DIR/AppIcon.icns" ]; then
    echo "🎨 Uygulama ikonu oluşturuluyor..."
    python3 "$DIR/scripts/generate_icon.py"
fi
cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# 3. Info.plist oluşturma
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
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# 4. Ad-hoc imzalama (macOS Gatekeeper uyumluluğu için)
echo "🔏 Kod imzalanıyor..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "✅ Tamamlandı! YouTubeWidget.app hazırlandı:"
echo "   📍 $APP_DIR"

# 5. Opsiyonel parametreler
if [[ "$*" == *"--install"* ]]; then
    echo "🚀 /Applications dizinine yükleniyor..."
    rm -rf "/Applications/YouTubeWidget.app"
    cp -R "$APP_DIR" /Applications/
    echo "🎉 Başarıyla /Applications altına yüklendi!"
fi

if [[ "$*" == *"--run"* ]]; then
    echo "▶️  Uygulama başlatılıyor..."
    open "$APP_DIR"
fi
