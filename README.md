# VPN por país para o celular, rodando no Mac

O celular conecta no Mac (app **Outline**) e sai na internet pelo **ProtonVPN grátis**, no país que você escolher no Mac.
Tudo grátis: ProtonVPN Free (sem limite de dados), gluetun no OrbStack e o app Outline.

Dois modos:

    rápido:  celular (Outline) ─▶ Mac :8388 (gluetun) ─WireGuard─▶ ProtonVPN ─▶ internet
    --tor:   celular (Outline) ─▶ Mac :8388 (gluetun) ─▶ Tor ─OpenVPN TCP─▶ ProtonVPN ─▶ internet

No modo `--tor` o Proton só vê um nó de saída do Tor, nunca o IP de casa; os sites veem um IP do Proton no país escolhido.
Custo: fica lento (medido em 2026-11-03: ~95 KB/s e ~4 s para abrir uma página).

## Primeira vez

1. `./vpn setup`: gera a senha do celular e pede a chave WireGuard do Proton (opcional, só para o modo rápido).
2. Modo `--tor`: crie a conta Proton pelo Tor Browser; no painel, pegue o usuário/senha **OpenVPN/IKEv2** e baixe os
   arquivos OpenVPN (GNU/Linux, **TCP**, servidores grátis) em Downloads; depois `./vpn setup-tor`.
3. `./vpn up eua` (rápido) ou `./vpn up eua --tor`
3. `./vpn celular`: mostra a chave `ss://…` (e o QR code). Instale o **Outline** no celular, toque em **+**, cole a chave e conecte.
4. Reserve um IP fixo para o Mac no roteador (DHCP), senão a chave muda quando o IP do Mac mudar.

## Dia a dia

    ./vpn up [país] [--tor|--rapido]   # liga (lembra o último país e modo)
    ./vpn pais japao      # troca de país (reconecta em segundos); o celular continua no Outline
    ./vpn paises          # países disponíveis
    ./vpn status          # IP e país de saída
    ./vpn down            # desliga

Países grátis: eua, canada, mexico, holanda, suica, noruega, polonia, romenia, japao, singapura.

## O que está protegido (e o que não está)

Protegido, e conferido em 2026-11-03:
- **Kill switch do lado do Mac:** se o túnel cair, o tráfego do celular que chega ao Mac não sai pelo IP de casa (gluetun bloqueia tudo por padrão, IPv4 e IPv6; DNS pelo túnel).
- **Modo Tor confere o caminho:** ao ligar e a cada 5 s, o `./vpn` verifica que a conexão com o Proton só passa pelo Tor; se aparecer conexão direta, desliga tudo.
- **Troca de rede desliga tudo:** a porta 8388 só abre no IP do Mac na rede em que você ligou. Se a rede ou o IP mudarem (café, escritório, outro Wi-Fi), um vigia derruba a VPN e avisa por notificação. Nada religa sozinho, nem depois de reiniciar o Mac.
- **Segredos fora do `docker inspect`:** credenciais e senha do celular entram no container como arquivos (`/run/secrets`), não como variáveis.
- **Painel do gluetun fechado:** quem tem a chave do celular não consegue desligar a VPN pelo proxy.
- **Tor estável:** o estado do Tor fica num volume, então ele mantém os mesmos nós de entrada (menos exposição) e trocar de país não reinicia o Tor.

**Não** protegido:
- **Este Mac não passa pela VPN.** Só o celular conectado no Outline.
- **O celular não tem kill switch próprio.** Se o Mac dormir, a VPN cair ou a rede mudar, o celular volta a navegar pela internet de casa.
  - Android: Configurações → VPN → Outline → ative "VPN sempre ativa" e "Bloquear conexões sem VPN".
  - iPhone: não há bloqueio garantido; confira o ícone do Outline antes de usar.
- **Identidade:** o Proton só não vê seu IP se a conta for usada **exclusivamente pelo Tor** (cadastro, painel e conexões). Sem modo rápido com essa conta, sem abrir o painel num navegador comum.
- **O que o celular entrega por si só:** fuso horário, idioma, GPS e contas logadas continuam dizendo quem e onde você está. IPv6 do celular não foi testado.
- Streaming (Netflix etc.) costuma bloquear IPs de VPN grátis. Modo Tor é lento (~95 KB/s).

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `Sem arquivo .ovpn de <país>` | Baixe o .ovpn TCP grátis desse país no painel e rode `./vpn setup-tor`. |
| Modo `--tor` não conecta | O circuito do Tor pode estar ruim: rode o mesmo comando de novo (sorteia outro servidor). |
| `A rede do Mac mudou: VPN desligada` | Normal ao trocar de Wi-Fi. Rode `./vpn up` de novo e, se o IP do Mac mudou, atualize a chave no Outline (`./vpn celular`). |
| `Conexão fora do Tor detectada` | Algo tentou falar com o Proton sem o Tor; tudo foi desligado. Rode `./vpn up` de novo; se repetir, troque o arquivo .ovpn daquele país. |
| `O túnel não conectou` | Chave do Proton errada ou revogada: gere outra e rode `./vpn setup --force`. |
| Celular conecta mas não navega | `./vpn status`; se o IP do Mac mudou, `./vpn celular` e troque a chave no Outline. |
| Outro dispositivo já usa a conta Proton | O plano grátis permite 1 conexão: desconecte o outro. |
| `./vpn logs` | Log do túnel, ao vivo. |
