#!/bin/bash
# Instala o Outis a partir deste repositório: compila na sua máquina e copia para /Applications.
# Uso: ./install.sh
set -euo pipefail
cd "$(dirname "$0")"

falta() { echo "✗ $1" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || falta "O Outis só roda no macOS."
maior="$(sw_vers -productVersion | cut -d. -f1)"
[ "$maior" -ge 14 ] || falta "Precisa do macOS 14 ou mais novo."
xcode-select -p >/dev/null 2>&1 || falta "Instale as Command Line Tools: xcode-select --install"
command -v swift >/dev/null || falta "Swift não encontrado: xcode-select --install"

if command -v brew >/dev/null; then
  command -v tor >/dev/null || { echo "→ Instalando o Tor (Homebrew)..."; brew install tor; }
elif ! command -v tor >/dev/null && [ ! -x "/Applications/Tor Browser.app/Contents/MacOS/Tor/tor" ]; then
  echo "! Tor não encontrado: a rota \"Este Mac\" precisa do Homebrew (brew install tor) ou do Tor Browser."
fi

echo "→ Compilando o Outis $(cat VERSION)..."
app/build.sh

echo
echo "Pronto. Para o celular, instale também o OrbStack; para a conta da VPN, o Tor Browser:"
echo "  brew install --cask orbstack tor-browser"
echo "Abra o Outis em /Applications e permita as notificações na primeira vez."
