#!/usr/bin/env bash
# Guarda as credenciais OpenVPN do Proton e os .ovpn (TCP) em ~/Library/Application Support/vpn-pais/secrets/, sem passar pelo chat.
set -euo pipefail
DATA="${VPN_DATA:-$HOME/Library/Application Support/vpn-pais}"
umask 077
mkdir -p "$DATA/secrets/ovpn"
cd "$DATA"
printf 'Usuário OpenVPN/IKEv2 (do painel do Proton): '
IFS= read -r u
printf 'Senha OpenVPN/IKEv2 (não aparece ao digitar): '
IFS= read -rs p; echo
[ -n "$u" ] && [ -n "$p" ] || { echo "Usuário e senha são obrigatórios."; exit 1; }
printf '%s\n%s\n' "$u" "$p" > secrets/openvpn-auth.txt
n=0
for d in "$HOME/Downloads" "$HOME/Library/Application Support/TorBrowser-Data/Browser/Downloads" "/Applications/Tor Browser.app/../Downloads"; do
  for f in "$d"/*.ovpn; do
    [ -f "$f" ] || continue
    cp "$f" secrets/ovpn/ && n=$((n+1))
  done
done
echo "Credenciais guardadas. Arquivos .ovpn copiados: $n"
ls secrets/ovpn 2>/dev/null | sed 's/^/  /'
[ "$n" -gt 0 ] || echo "Nenhum .ovpn achado em Downloads: baixe pelo painel (TCP, servidor grátis) e rode de novo."
