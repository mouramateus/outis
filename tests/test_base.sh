credenciais_vao_pro_keychain() {
  out="$(printf 'u1\np"1\n' | $VPN credenciais-openvpn)"
  assert_eq "$out" ok
  assert_eq "$(cat "$FAKE_KC/vpn-pais-teste.openvpn-user")" u1
  assert_eq "$(cat "$FAKE_KC/vpn-pais-teste.openvpn-password")" 'p"1'
}
senha_nao_passa_pelo_argv() {
  printf 'u1\nsegredo\n' | $VPN credenciais-openvpn >/dev/null
  assert_not_contains "$(cat "$FAKE_LOG")" segredo
}
migrar_move_e_apaga() {
  printf 'u2\np2\n' > "$VPN_DATA/secrets/openvpn-auth.txt"
  assert_eq "$($VPN migrar-keychain)" "migrado: 1"
  assert_no_file "$VPN_DATA/secrets/openvpn-auth.txt"
  assert_eq "$(cat "$FAKE_KC/vpn-pais-teste.openvpn-password")" p2
  assert_eq "$($VPN migrar-keychain)" "migrado: 0"
}
migrar_nao_apaga_se_keychain_falha() {
  printf 'u2\np2\n' > "$VPN_DATA/secrets/openvpn-auth.txt"
  FAKE_KC_FAIL=1 $VPN migrar-keychain >/dev/null 2>&1
  assert_file "$VPN_DATA/secrets/openvpn-auth.txt"
}
compose_recebe_credenciais_do_keychain() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn
  FAKE_RUNNING=true FAKE_HEALTH=healthy $VPN up >/dev/null 2>&1
  assert_contains "$(cat "$FAKE_LOG")" "OPENVPN_USER=u1"
}
projeto_configuravel() {
  $VPN down >/dev/null 2>&1
  assert_contains "$(cat "$FAKE_LOG")" "-p vpn-teste"
}
sem_modo_wireguard() {
  assert_not_contains "$($VPN help)" rapido
}
for f in credenciais_vao_pro_keychain senha_nao_passa_pelo_argv migrar_move_e_apaga migrar_nao_apaga_se_keychain_falha compose_recebe_credenciais_do_keychain projeto_configuravel sem_modo_wireguard; do t $f; done
