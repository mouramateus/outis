#!/bin/bash
# Instala o Outis em /Applications e o comando `outis`.
# Uso: ./install.sh            baixa o app pronto da versão deste repositório (Releases do GitHub)
#      ./install.sh --compilar compila aqui (precisa do Xcode completo)
set -euo pipefail
cd "$(dirname "$0")"
REPO="mouramateus/outis"
VERSAO="$(cat VERSION)"
APP="/Applications/Outis.app"

falta() { echo "✗ $1" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || falta "O Outis só roda no macOS."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || falta "Precisa do macOS 14 ou mais novo."

if command -v brew >/dev/null; then
  for f in tor qrencode; do
    brew list --formula "$f" >/dev/null 2>&1 || { echo "→ Instalando $f (Homebrew)..."; brew install "$f"; }
  done
elif ! command -v tor >/dev/null && [ ! -x "/Applications/Tor Browser.app/Contents/MacOS/Tor/tor" ]; then
  echo "! Tor não encontrado: a rota \"Este Mac\" precisa do Homebrew (brew install tor) ou do Tor Browser."
fi

if [ "${1:-}" = --compilar ]; then
  echo "→ Compilando o Outis $VERSAO..."
  app/build.sh
else
  echo "→ Baixando o Outis $VERSAO..."
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl -fL --progress-bar -o "$tmp/Outis.zip" \
    "https://github.com/$REPO/releases/download/v$VERSAO/Outis-$VERSAO.zip"
  ditto -x -k "$tmp/Outis.zip" "$tmp"
  osascript -e 'tell application "Outis" to quit' >/dev/null 2>&1 || true
  rm -rf "$APP"
  ditto "$tmp/Outis.app" "$APP"
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  echo "Instalado em $APP"
fi

BIN_DIR="$(command -v brew >/dev/null && echo "$(brew --prefix)/bin" || echo /usr/local/bin)"
if [ -w "$BIN_DIR" ]; then
  ln -sfn "$APP/Contents/Resources/cli/vpn" "$BIN_DIR/outis"
  echo "Comando: outis ($BIN_DIR/outis)"
else
  echo "! Sem permissão em $BIN_DIR: o comando fica em $APP/Contents/Resources/cli/vpn"
fi

echo
echo "Pronto. Para o celular, instale também o OrbStack; para a conta da VPN, o Tor Browser:"
echo "  brew install --cask orbstack tor-browser"
echo "Abra o Outis em /Applications e permita as notificações na primeira vez."
