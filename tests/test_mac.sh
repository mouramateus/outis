mst() { $VPN status --json 2>/dev/null; }
ligar_rota2() { export FAKE_RUNNING=true FAKE_HEALTH=healthy; }

mac_liga_e_ativa_proxy() {
  out="$(VPN_ESPERA=3 $VPN mac on 2>&1)"
  assert_contains "$out" "etapa: tor"
  assert_file "$FAKE_PROXY"
  assert_contains "$(cat "$FAKE_LOG")" "-setsocksfirewallproxy Wi-Fi 127.0.0.1 9160"
  assert_contains "$(cat "$FAKE_LOG")" "-setsocksfirewallproxy USB LAN 127.0.0.1 9160"
  assert_not_contains "$(cat "$FAKE_LOG")" "Bluetooth"
  s="$(mst)"; assert_eq "$(echo "$s" | jqr .mac_estado)" ligada; assert_eq "$(echo "$s" | jqr .mac_ip)" 5.5.5.5
}
mac_sem_tor_provado_nao_ativa_proxy() {
  export FAKE_CURL='{"IsTor":false,"IP":"1.2.3.4"}'
  out="$(VPN_ESPERA=3 $VPN mac on 2>&1)"
  assert_contains "$out" "Erro"; assert_no_file "$FAKE_PROXY"; assert_eq "$(mst | jqr .mac_estado)" desligada
}
mac_bootstrap_falho_nao_ativa_proxy() {
  export FAKE_TOR_LOG='nada'
  VPN_ESPERA=1 $VPN mac on >/dev/null 2>&1
  assert_no_file "$FAKE_PROXY"; assert_no_file "$VPN_DATA/secrets/run/mac/tor.pid"
}
mac_desliga_restaura_tudo() {
  VPN_ESPERA=3 $VPN mac on >/dev/null 2>&1
  P="$(cat "$VPN_DATA/secrets/run/mac/tor.pid")"
  assert_contains "$($VPN mac off 2>&1)" Desligado
  assert_no_file "$FAKE_PROXY"
  kill -0 "$P" 2>/dev/null && no "tor continua vivo" || ok
  assert_eq "$(mst | jqr .mac_estado)" desligada
}
mac_tor_morto_com_proxy_e_erro_sem_tirar_proxy() {
  VPN_ESPERA=3 $VPN mac on >/dev/null 2>&1
  kill "$(cat "$VPN_DATA/secrets/run/mac/tor.pid")"; sleep 0.3
  assert_eq "$(mst | jqr .mac_estado)" erro
  assert_file "$FAKE_PROXY"
}
mac_saida_fixa() {
  VPN_ESPERA=3 $VPN mac on --saida de >/dev/null 2>&1
  assert_contains "$(cat "$VPN_DATA/secrets/run/mac/torrc")" 'ExitNodes {de}'
  assert_eq "$(mst | jqr .mac_saida)" de
}
mac_saida_invalida() { assert_contains "$($VPN mac on --saida brasil 2>&1)" "inválido"; assert_no_file "$FAKE_PROXY"; }
conflito_mac_com_celular_ligado() {
  ligar_rota2
  out="$(VPN_ESPERA=3 $VPN mac on 2>&1)"
  assert_contains "$out" "celular vai perder a VPN"; assert_no_file "$FAKE_PROXY"
  assert_eq "$(mst | jqr .conflito_orbstack)" true
}
conflito_confirmado_derruba_o_celular() {
  ligar_rota2
  VPN_ESPERA=3 $VPN mac on --derrubar-celular >/dev/null 2>&1
  assert_file "$FAKE_PROXY"; assert_contains "$(cat "$FAKE_LOG")" "down --remove-orphans"
}
sem_conflito_com_orbstack_none() {
  ligar_rota2; export FAKE_ORB_PROXY=none
  VPN_ESPERA=3 $VPN mac on >/dev/null 2>&1
  assert_file "$FAKE_PROXY"; assert_not_contains "$(cat "$FAKE_LOG")" "down --remove-orphans"
  assert_eq "$(mst | jqr .conflito_orbstack)" false
}
conflito_celular_com_mac_ligado() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; VPN_ESPERA=3 $VPN mac on >/dev/null 2>&1
  out="$($VPN up 2>&1)"
  assert_contains "$out" "Mac vai perder a VPN"; assert_file "$FAKE_PROXY"; assert_not_contains "$(cat "$FAKE_LOG")" " up "
}
conflito_confirmado_derruba_o_mac() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; VPN_ESPERA=3 $VPN mac on >/dev/null 2>&1
  export FAKE_RUNNING=true FAKE_HEALTH=healthy FAKE_NETSTAT='tcp 0 0 172.31.251.3:5000 172.31.251.2:9050 ESTABLISHED' FAKE_LOGS='Bootstrapped 100%' FAKE_PUBLICIP='{"public_ip":"1.1.1.1"}'
  VPN_ESPERA=1 $VPN up --derrubar-mac >/dev/null 2>&1
  assert_no_file "$FAKE_PROXY"; assert_contains "$(cat "$FAKE_LOG")" " up "
}
for f in mac_liga_e_ativa_proxy mac_sem_tor_provado_nao_ativa_proxy mac_bootstrap_falho_nao_ativa_proxy mac_desliga_restaura_tudo mac_tor_morto_com_proxy_e_erro_sem_tirar_proxy mac_saida_fixa mac_saida_invalida conflito_mac_com_celular_ligado conflito_confirmado_derruba_o_celular sem_conflito_com_orbstack_none conflito_celular_com_mac_ligado conflito_confirmado_derruba_o_mac; do t $f; done
