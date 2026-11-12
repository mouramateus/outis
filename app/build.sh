#!/bin/bash
# Compila o Outis, embute o CLI e (por padrão) instala em /Applications.
# Uso: app/build.sh [--sem-instalar] [--universal]
#   --sem-instalar  só gera app/dist/Outis.app e imprime o caminho
#   --universal     Apple Silicon + Intel (precisa do Xcode completo, não só das Command Line Tools)
# Extra para o swift build: SWIFT_BUILD_FLAGS (ex.: --disable-sandbox, usado pelo Homebrew).
set -euo pipefail
cd "$(dirname "$0")"
NOME="Outis"
DIST="dist/$NOME.app"
VERSAO="$(cat ../VERSION)"
INSTALAR=1; ARCHS=()
for a in "$@"; do
  case "$a" in
    --sem-instalar) INSTALAR=0 ;;
    --universal) ARCHS=(--arch arm64 --arch x86_64) ;;
    *) echo "Opção desconhecida: $a" >&2; exit 2 ;;
  esac
done

# shellcheck disable=SC2086
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} ${SWIFT_BUILD_FLAGS:-}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} ${SWIFT_BUILD_FLAGS:-} --show-bin-path)/VPNPais"

rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources/cli"
cp "$BIN" "$DIST/Contents/MacOS/VPNPais"
cp -R ../vpn ../compose.yaml ../guardar-credenciais-tor.sh ../tor ../config "$DIST/Contents/Resources/cli/"
cp AppIcon.icns "$DIST/Contents/Resources/AppIcon.icns"
cat > "$DIST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>io.github.mouramateus.outis</string>
  <key>CFBundleName</key><string>$NOME</string>
  <key>CFBundleDisplayName</key><string>$NOME</string>
  <key>CFBundleExecutable</key><string>VPNPais</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSAO</string>
  <key>CFBundleVersion</key><string>$VERSAO</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$DIST"
[ "$INSTALAR" = 1 ] || { echo "$PWD/$DIST"; exit 0; }
osascript -e "tell application \"$NOME\" to quit" >/dev/null 2>&1 || true
rm -rf "/Applications/$NOME.app"
cp -R "$DIST" "/Applications/$NOME.app"
echo "Instalado em /Applications/$NOME.app"
