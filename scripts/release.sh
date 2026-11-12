#!/bin/bash
# Gera o pacote de uma versão: dist/Outis-<versão>.zip (Apple Silicon + Intel) e o sha256 para o Cask.
# Precisa do Xcode completo. Depois: crie a tag v<versão>, anexe o zip ao Release do GitHub
# e atualize version/sha256 em Casks/outis.rb.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSAO="$(cat VERSION)"
APP="$(app/build.sh --sem-instalar --universal | tail -1)"
lipo -archs "$APP/Contents/MacOS/VPNPais"
mkdir -p dist
ZIP="dist/Outis-$VERSAO.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
shasum -a 256 "$ZIP"
