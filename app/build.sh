#!/bin/bash
# Compila o app (Apple Silicon + Intel), embute o CLI e instala em /Applications.
# Uso: app/build.sh [--sem-instalar]
set -euo pipefail
cd "$(dirname "$0")"
NOME="Outis"
DIST="dist/$NOME.app"

swift build -c release --arch arm64 --arch x86_64
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources/cli"
cp .build/apple/Products/Release/VPNPais "$DIST/Contents/MacOS/VPNPais"
cp -R ../vpn ../compose.yaml ../guardar-credenciais-tor.sh ../tor ../config "$DIST/Contents/Resources/cli/"
# Rota 1: Tor nativo, copiado do Tor Browser instalado (universal).
TB="/Applications/Tor Browser.app/Contents"
[ -x "$TB/MacOS/Tor/tor" ] || { echo "Instale o Tor Browser para compilar: o app embute o Tor dele."; exit 1; }
mkdir -p "$DIST/Contents/Resources/cli/tor-nativo"
cp "$TB/MacOS/Tor/tor" "$TB/MacOS/Tor/libevent-2.1.7.dylib" "$TB/Resources/TorBrowser/Tor/geoip" "$TB/Resources/TorBrowser/Tor/geoip6" "$DIST/Contents/Resources/cli/tor-nativo/"
codesign --force --sign - "$DIST/Contents/Resources/cli/tor-nativo/libevent-2.1.7.dylib" "$DIST/Contents/Resources/cli/tor-nativo/tor"
[ -f dist/AppIcon.icns ] || swift make-icon.swift dist
cp dist/AppIcon.icns "$DIST/Contents/Resources/AppIcon.icns"
cat > "$DIST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>br.local.vpn-pais</string>
  <key>CFBundleName</key><string>$NOME</string>
  <key>CFBundleDisplayName</key><string>$NOME</string>
  <key>CFBundleExecutable</key><string>VPNPais</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$DIST"
[ "${1:-}" = --sem-instalar ] && { echo "$DIST"; exit 0; }
osascript -e 'tell application "Outis" to quit' >/dev/null 2>&1 || true
rm -rf "/Applications/$NOME.app"
cp -R "$DIST" "/Applications/$NOME.app"
echo "Instalado em /Applications/$NOME.app"
