# Ambiente isolado para testar o CLI: dados, Keychain, docker e rede falsos.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VPN="/bin/bash $ROOT/vpn"
PASS=0; FAIL=0

setup_env() {
  T="$(mktemp -d)"
  export VPN_DATA="$T/data" VPN_KC_SERVICE=vpn-pais-teste VPN_PROJECT=vpn-teste
  export FAKE_KC="$T/kc" FAKE_LOG="$T/log"
  export PATH="$ROOT/tests/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  export VPN_ESPERA=0 VPN_SEM_VIGIA=1
  unset FAKE_DOCKER_DOWN FAKE_DOCKER_HANG FAKE_RUNNING FAKE_HEALTH FAKE_PUBLICIP FAKE_NETSTAT FAKE_LOGS FAKE_KC_FAIL FAKE_SEM_REDE FAKE_COMPOSE_HANG
  mkdir -p "$VPN_DATA/secrets/ovpn" "$VPN_DATA/secrets/run" "$FAKE_KC"
  : > "$FAKE_LOG"
  printf 'SS_PASSWORD=abc123\nSS_PORT=8388\nVPN_COUNTRY=United States\nVPN_MODE=tor\n' > "$VPN_DATA/.env"
}

ovpn() { printf 'client\nremote 1.2.3.4 443\n' > "$VPN_DATA/secrets/ovpn/$1"; }
creds() { printf 'u1' > "$FAKE_KC/$VPN_KC_SERVICE.openvpn-user"; printf 'p1' > "$FAKE_KC/$VPN_KC_SERVICE.openvpn-password"; }

ok() { PASS=$((PASS+1)); }
no() { FAIL=$((FAIL+1)); printf '  FALHOU %s: %s\n' "$NOME" "$*"; }
assert_eq() { [ "$1" = "$2" ] && ok || no "esperado [$2], veio [$1]"; }
assert_contains() { case "$1" in *"$2"*) ok ;; *) no "sem [$2] em [$1]" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) no "não devia ter [$2] em [$1]" ;; *) ok ;; esac; }
assert_file() { [ -e "$1" ] && ok || no "arquivo não existe: $1"; }
assert_no_file() { [ ! -e "$1" ] && ok || no "arquivo não devia existir: $1"; }
jqr() { /usr/bin/jq -r "$1"; }

# Roda uma função de teste num ambiente limpo; contagem volta por arquivo.
t() {
  NOME="$1"; setup_env
  "$1"
  rm -rf "$T"
}
