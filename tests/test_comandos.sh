init_cria_e_nao_sobrescreve() { rm "$VPN_DATA/.env"; assert_eq "$($VPN init)" ok; assert_contains "$(cat "$VPN_DATA/.env")" SS_PASSWORD=; assert_eq "$($VPN init)" ja-existe; }
paises_json() { ovpn us-free-1.protonvpn.tcp.ovpn; s="$($VPN paises --json)"; assert_eq "$(echo "$s" | jqr length)" 10; assert_eq "$(echo "$s" | jqr '.[0].ovpn')" 1; assert_eq "$(echo "$s" | jqr '.[0].atual')" true; assert_eq "$(echo "$s" | jqr '.[2].ovpn')" 0; assert_eq "$(echo "$s" | jqr '.[2].codigo')" mx; }
celular_json_igual_ao_texto() { s="$($VPN celular --json)"; c="$(echo "$s" | jqr .chave)"; assert_contains "$($VPN celular)" "$c"; assert_eq "$(echo "$s" | jqr .ip_mac)" 192.168.1.52; assert_eq "$(echo "$s" | jqr .porta)" 8388; }
conexoes_filtra_locais() {
  export FAKE_LSOF='OrbStack 1 u 1u IPv4 0 0t0 TCP 192.168.1.52:8388->192.168.1.40:5000 (ESTABLISHED)
OrbStack 1 u 2u IPv4 0 0t0 TCP 192.168.1.52:8388->192.168.1.40:5001 (ESTABLISHED)
OrbStack 1 u 3u IPv4 0 0t0 TCP 192.168.1.52:8388->192.168.1.52:6000 (ESTABLISHED)'
  s="$($VPN conexoes --json)"; assert_eq "$(echo "$s" | jqr length)" 1; assert_eq "$(echo "$s" | jqr '.[0].ip')" 192.168.1.40; unset FAKE_LSOF
}
caminho_grava_desligada() { $VPN caminho sotor --saida jp >/dev/null; assert_contains "$(cat "$VPN_DATA/.env")" VPN_MODE=sotor; assert_contains "$(cat "$VPN_DATA/.env")" VPN_SAIDA=jp; }
caminho_nao_aceita_proton() { out="$($VPN caminho proton 2>&1)"; assert_contains "$out" "Erro"; assert_contains "$(cat "$VPN_DATA/.env")" VPN_MODE=tor; }
caminho_recusa_com_vpn_ligada() { export FAKE_RUNNING=true; out="$($VPN caminho sotor 2>&1)"; assert_contains "$out" "ligada"; assert_contains "$(cat "$VPN_DATA/.env")" VPN_MODE=tor; }
importar_filtra() {
  d="$T/dl"; mkdir "$d"; printf 'remote 1\n' > "$d/us-free-9.protonvpn.tcp.ovpn"; printf 'x' > "$d/foo.ovpn"; printf 'x' > "$d/us-free-9.protonvpn.udp.ovpn"; printf 'http-proxy 1 2\n' > "$d/jp-free-1.protonvpn.tcp.ovpn"
  s="$($VPN importar-ovpn "$d")"; assert_eq "$(echo "$s" | jqr .importados)" 1; assert_eq "$(echo "$s" | jqr .por_pais.us)" 1; assert_eq "$(echo "$s" | jqr .recusados)" 1
  assert_eq "$(ls "$VPN_DATA/secrets/ovpn")" us-free-9.protonvpn.tcp.ovpn
}
for f in init_cria_e_nao_sobrescreve paises_json celular_json_igual_ao_texto conexoes_filtra_locais caminho_grava_desligada caminho_nao_aceita_proton caminho_recusa_com_vpn_ligada importar_filtra; do t $f; done
