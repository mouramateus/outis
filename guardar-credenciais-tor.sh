#!/bin/bash
# Guarda as credenciais OpenVPN do Proton no Keychain e importa os .ovpn (TCP), sem passar pelo chat.
set -euo pipefail
VPN="$(cd "$(dirname "$0")" && pwd)/vpn"
"$VPN" init >/dev/null
printf 'Usuário OpenVPN/IKEv2 (do painel do Proton): '
IFS= read -r u
printf 'Senha OpenVPN/IKEv2 (não aparece ao digitar): '
IFS= read -rs p; echo
printf '%s\n%s\n' "$u" "$p" | "$VPN" credenciais-openvpn >/dev/null
echo "Credenciais guardadas no Keychain."
"$VPN" importar-ovpn
