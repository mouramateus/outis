st() { $VPN status --json 2>/dev/null; }
est() { st | jqr .estado; }
TOR_OK='tcp 0 0 172.31.251.3:5000 172.31.251.2:9050 ESTABLISHED'
TOR_RUIM='tcp 0 0 172.31.251.3:6000 89.187.180.55:8443 ESTABLISHED'
IP_US='{"public_ip":"89.1.1.1","city":"Chicago","country":"United States"}'
ligar_fake() { export FAKE_RUNNING=true FAKE_HEALTH=healthy FAKE_PUBLICIP="$IP_US" FAKE_NETSTAT="$TOR_OK" FAKE_LOGS='Bootstrapped 100% (done)'; }

orbstack_fechado() { export FAKE_DOCKER_DOWN=1; s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" desligada; assert_eq "$(echo "$s" | jqr .aviso)" orbstack; assert_not_contains "$(cat "$FAKE_LOG")" open-chamado; }
orbstack_travado_responde_rapido() { export FAKE_DOCKER_HANG=1; a=$(date +%s); s="$(st)"; b=$(date +%s); [ $((b-a)) -le 5 ] && ok || no "demorou $((b-a)) s"; assert_eq "$(echo "$s" | jqr .aviso)" orbstack; }
sem_env_nao_morre() { rm "$VPN_DATA/.env"; s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" desligada; assert_eq "$(echo "$s" | jqr .aviso)" sem_config; }
sem_rede_nao_morre() { export FAKE_SEM_REDE=1; s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" desligada; assert_eq "$(echo "$s" | jqr .ip_mac)" null; }
parada() { assert_eq "$(est)" desligada; }
conectando_sem_health() { ligar_fake; export FAKE_HEALTH=starting; assert_eq "$(est)" conectando; }
ligada_com_ip_e_caminho() { ligar_fake; s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" ligada; assert_eq "$(echo "$s" | jqr .tor_conferido)" true; assert_eq "$(echo "$s" | jqr .ip_saida)" 89.1.1.1; assert_eq "$(echo "$s" | jqr .cidade)" Chicago; assert_eq "$(echo "$s" | jqr .rede)" wifi; assert_eq "$(echo "$s" | jqr .codigo)" us; }
sem_ip_nao_e_ligada() { ligar_fake; export FAKE_PUBLICIP='{"public_ip":""}'; assert_eq "$(est)" conectando; }
fora_do_tor_nao_e_ligada() { ligar_fake; export FAKE_NETSTAT="$TOR_OK
$TOR_RUIM"; assert_eq "$(est)" conectando; }
erro_vale_com_vpn_parada() { echo '{"codigo":"credenciais","mensagem":"recusadas"}' > "$VPN_DATA/secrets/run/erro.json"; s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" erro; assert_eq "$(echo "$s" | jqr .codigo_erro)" credenciais; }
erro_nao_vence_tunel_saudavel() { ligar_fake; echo '{"codigo":"tor","mensagem":"x"}' > "$VPN_DATA/secrets/run/erro.json"; assert_eq "$(est)" ligada; }
pais_diferente_avisa() { ligar_fake; export FAKE_PUBLICIP='{"public_ip":"1.1.1.1","country":"Canada"}'; s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" ligada; assert_eq "$(echo "$s" | jqr .aviso)" pais_diferente; }
credenciais_no_status() { assert_eq "$(st | jqr .credenciais)" false; creds; assert_eq "$(st | jqr .credenciais)" true; }

lock_vivo() { sleep 30 & L=$!; mkdir "$VPN_DATA/secrets/run/lock"; echo "$L" > "$VPN_DATA/secrets/run/lock/pid"; echo up > "$VPN_DATA/secrets/run/lock/op"; }
operacao_exposta() { lock_vivo; assert_eq "$(st | jqr .operacao)" up; kill "$L"; }
trava_recusa_segunda() { lock_vivo; out="$($VPN down 2>&1)"; assert_contains "$out" "Outra operação em andamento"; kill "$L"; }
trava_orfa_e_removida() { mkdir "$VPN_DATA/secrets/run/lock"; echo 999999 > "$VPN_DATA/secrets/run/lock/pid"; assert_contains "$($VPN down 2>&1)" Desligada; }
trava_liberada_em_falha() { creds; ovpn us-free-1.protonvpn.tcp.ovpn; $VPN up >/dev/null 2>&1; assert_no_file "$VPN_DATA/secrets/run/lock"; }
trava_liberada_em_sigterm() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; export FAKE_COMPOSE_HANG=1
  /bin/bash "$ROOT/vpn" up >/dev/null 2>&1 & P=$!
  sleep 1; assert_file "$VPN_DATA/secrets/run/lock"; kill -TERM "$P"; sleep 1
  kill -0 "$P" 2>/dev/null && no "processo continua vivo"; assert_no_file "$VPN_DATA/secrets/run/lock"
  unset FAKE_COMPOSE_HANG; pgrep -f "sleep 30" >/dev/null; wait "$P" 2>/dev/null
}
erro_credenciais_tem_codigo() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn
  export FAKE_RUNNING=true FAKE_HEALTH=starting FAKE_LOGS='Bootstrapped 100% AUTH_FAILED'
  VPN_ESPERA=1 $VPN up >/dev/null 2>&1
  assert_contains "$(cat "$VPN_DATA/secrets/run/erro.json")" '"codigo":"credenciais"'
}
etapas_impressas() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; ligar_fake
  out="$(VPN_ESPERA=1 $VPN up 2>&1)"
  assert_contains "$out" "etapa: tor"; assert_contains "$out" "etapa: proton"; assert_contains "$out" "etapa: conferindo"
}
tor_usa_socks() { creds; ovpn us-free-1.protonvpn.tcp.ovpn; ligar_fake; VPN_ESPERA=1 $VPN up >/dev/null 2>&1; assert_contains "$(cat "$VPN_DATA/secrets/run/active.ovpn")" "socks-proxy 172.31.251.2 9050"; assert_eq "$(st | jqr .modo)" tor; }
so_proton_exige_confirmacao() { creds; ovpn us-free-1.protonvpn.tcp.ovpn; out="$($VPN up --so-proton 2>&1)"; assert_contains "$out" "anonimato"; assert_not_contains "$(cat "$FAKE_LOG")" "compose"; }
so_proton_nao_fica_salvo() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; ligar_fake
  VPN_ESPERA=1 $VPN up --so-proton --confirmo-quebrar-anonimato >/dev/null 2>&1
  assert_not_contains "$(cat "$VPN_DATA/secrets/run/active.ovpn")" socks-proxy
  assert_eq "$(st | jqr .modo)" proton
  assert_contains "$(cat "$VPN_DATA/.env")" "VPN_MODE=tor"
  $VPN down >/dev/null 2>&1; assert_eq "$(st | jqr .modo)" tor
}
so_tor_saida_fixa() {
  export FAKE_RUNNING=true FAKE_LOGS='Bootstrapped 100%'
  VPN_ESPERA=1 $VPN up --so-tor --saida us >/dev/null 2>&1
  assert_contains "$(cat "$VPN_DATA/secrets/run/tor/extra.conf")" 'ExitNodes {us}'
  assert_contains "$(cat "$FAKE_LOG")" "COMPOSE_PROFILES=sotor"
  s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" ligada; assert_eq "$(echo "$s" | jqr .modo)" sotor; assert_eq "$(echo "$s" | jqr .ip_saida)" null; assert_eq "$(echo "$s" | jqr .saida_tor)" us
}
so_tor_auto_sem_exitnodes() { export FAKE_RUNNING=true FAKE_LOGS='Bootstrapped 100%'; VPN_ESPERA=1 $VPN up --so-tor >/dev/null 2>&1; assert_not_contains "$(cat "$VPN_DATA/secrets/run/tor/extra.conf")" ExitNodes; }
ovpn_com_proxy_recusado() { creds; printf 'remote 1.1.1.1 443\nhttp-proxy 2.2.2.2 80\n' > "$VPN_DATA/secrets/ovpn/us-free-1.protonvpn.tcp.ovpn"; out="$($VPN up 2>&1)"; assert_contains "$out" recusado; assert_not_contains "$(cat "$FAKE_LOG")" " up "; }
pais_sem_ovpn_nao_derruba() { creds; ligar_fake; out="$($VPN up mexico 2>&1)"; assert_contains "$out" "Sem arquivo .ovpn"; assert_not_contains "$(cat "$FAKE_LOG")" "compose"; assert_no_file "$VPN_DATA/secrets/run/erro.json"; }

ip_de_reserva_quando_gluetun_falha() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; ligar_fake
  export FAKE_PUBLICIP='{"public_ip":""}' FAKE_IPINFO='{"ip":"9.9.9.9","city":"Houston","country":"US"}'
  VPN_ESPERA=1 $VPN up >/dev/null 2>&1
  s="$(st)"; assert_eq "$(echo "$s" | jqr .estado)" ligada; assert_eq "$(echo "$s" | jqr .ip_saida)" 9.9.9.9; assert_eq "$(echo "$s" | jqr .cidade)" Houston; assert_eq "$(echo "$s" | jqr .aviso)" null
}
ip_de_reserva_segunda_opcao() {
  creds; ovpn us-free-1.protonvpn.tcp.ovpn; ligar_fake
  export FAKE_PUBLICIP='{"public_ip":""}' FAKE_IPINFO='Too Many Requests' FAKE_IFCONFIG='{"ip":"8.8.8.8","city":"Dallas","country":"United States"}'
  VPN_ESPERA=1 $VPN up >/dev/null 2>&1
  assert_eq "$(st | jqr .ip_saida)" 8.8.8.8
}
cache_de_outra_conexao_nao_vale() {
  ligar_fake; export FAKE_PUBLICIP='{"public_ip":""}'
  printf '%s\n' '{"public_ip":"7.7.7.7","started":"2020-01-01T00:00:00Z"}' > "$VPN_DATA/secrets/run/saida.json"
  assert_eq "$(est)" conectando
}
vigia_completa_ip_faltando() {
  vigia_prepara; export FAKE_PUBLICIP='{"public_ip":""}' FAKE_IPINFO='{"ip":"6.6.6.6","city":"X","country":"US"}'
  $VPN _vigia
  assert_eq "$(st | jqr .estado)" ligada
}
pais_em_codigo_nao_avisa() { ligar_fake; export FAKE_PUBLICIP='{"public_ip":"1.1.1.1","country":"US"}'; assert_eq "$(st | jqr .aviso)" null; }

vigia_prepara() { ligar_fake; printf 'tor\n' > "$VPN_DATA/secrets/run/modo"; printf '192.168.1.52 192.168.1.254\n' > "$VPN_DATA/secrets/run/rede"; export VPN_VIGIA_UMA=1; }
vigia_rede_mudou() { vigia_prepara; printf '10.0.0.2 10.0.0.1\n' > "$VPN_DATA/secrets/run/rede"; $VPN _vigia; s="$(FAKE_RUNNING= st)"; assert_eq "$(echo "$s" | jqr .motivo_codigo)" rede; assert_contains "$(cat "$FAKE_LOG")" "compose"; assert_contains "$(cat "$FAKE_LOG")" osascript; }
vigia_sem_mudanca_nao_derruba() { vigia_prepara; $VPN _vigia; assert_not_contains "$(cat "$FAKE_LOG")" " down"; }
vigia_queda() { vigia_prepara; export FAKE_RUNNING=false; $VPN _vigia; assert_eq "$(st | jqr .motivo_codigo)" queda; }
vigia_fora_do_tor() { vigia_prepara; export FAKE_NETSTAT="$TOR_RUIM"; $VPN _vigia; assert_eq "$(FAKE_RUNNING= st | jqr .motivo_codigo)" fora_do_tor; }
vigia_nao_saudavel_passa_do_limite() { vigia_prepara; export FAKE_HEALTH=unhealthy VPN_VIGIA_LIMITE=0; $VPN _vigia; assert_eq "$(FAKE_RUNNING= st | jqr .motivo_codigo)" queda; }
vigia_app_aberto_nao_duplica_aviso() { vigia_prepara; export FAKE_RUNNING=false VPN_NOTIFY=app FAKE_APP_ABERTO=1; $VPN _vigia; assert_not_contains "$(cat "$FAKE_LOG")" osascript; unset VPN_NOTIFY FAKE_APP_ABERTO; }
vigia_app_fechado_avisa_sozinho() { vigia_prepara; export FAKE_RUNNING=false VPN_NOTIFY=app FAKE_APP_ABERTO=0; $VPN _vigia; assert_contains "$(cat "$FAKE_LOG")" osascript; unset VPN_NOTIFY FAKE_APP_ABERTO; }

for f in ip_de_reserva_quando_gluetun_falha ip_de_reserva_segunda_opcao cache_de_outra_conexao_nao_vale vigia_completa_ip_faltando pais_em_codigo_nao_avisa orbstack_fechado orbstack_travado_responde_rapido sem_env_nao_morre sem_rede_nao_morre parada conectando_sem_health ligada_com_ip_e_caminho sem_ip_nao_e_ligada fora_do_tor_nao_e_ligada erro_vale_com_vpn_parada erro_nao_vence_tunel_saudavel pais_diferente_avisa credenciais_no_status operacao_exposta trava_recusa_segunda trava_orfa_e_removida trava_liberada_em_falha trava_liberada_em_sigterm erro_credenciais_tem_codigo etapas_impressas tor_usa_socks so_proton_exige_confirmacao so_proton_nao_fica_salvo so_tor_saida_fixa so_tor_auto_sem_exitnodes ovpn_com_proxy_recusado pais_sem_ovpn_nao_derruba vigia_rede_mudou vigia_sem_mudanca_nao_derruba vigia_queda vigia_fora_do_tor vigia_nao_saudavel_passa_do_limite vigia_app_aberto_nao_duplica_aviso vigia_app_fechado_avisa_sozinho; do t $f; done
