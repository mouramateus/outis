# Outis

VPN por país para o celular, rodando no Mac. *Outis* é "Ninguém" em grego: o nome que Odisseu dá ao ciclope.

O celular conecta no Mac (app **Outline**) e sai na internet por outro país, com **Tor** e **ProtonVPN grátis** rodando no Mac.

Três caminhos:

    Tor + Proton (padrão):  iPhone (Outline) ─▶ Mac :8388 ─▶ Tor ─OpenVPN TCP─▶ Proton ─▶ internet
    Só Tor (experimental):  iPhone (Outline) ─▶ Mac :8388 ─▶ Tor ─▶ internet
    Só Proton:              iPhone (Outline) ─▶ Mac :8388 ─▶ Proton ─▶ internet

No padrão, o Proton só vê um nó de saída do Tor, nunca o IP de casa, e os sites veem um IP do Proton no país escolhido. Custo: fica lento (medido em 2026-11-03: ~95 KB/s e ~4 s para abrir uma página).

**Só Proton** quebra o anonimato da conta para sempre: o Proton passa a ver o IP de casa. Por isso exige confirmação e vale para uma conexão só. Ele nunca foi testado com a conta real, de propósito.

**Só Tor** não tem UDP: é experimental até ser testado com o Outline num iPhone de verdade.

## App

    app/build.sh       # compila (Apple Silicon + Intel), embute o CLI e instala em /Applications

O app **Outis** (macOS 14 ou mais novo) tem janela e ícone na barra de menus, e usa o CLI embutido nele, sem depender do SSD. Só foi testado no macOS 27. Precisa do OrbStack e, para a conta, do Tor Browser. Na primeira abertura, permita as notificações.

Fechar a janela ou sair (⌘Q) **não** desliga a VPN.

## Terminal

Dados e segredos ficam em `~/Library/Application Support/vpn-pais`; as credenciais OpenVPN, no Keychain.

    ./vpn setup-tor                     # credenciais OpenVPN e .ovpn (GNU/Linux, TCP, servidores grátis)
    ./vpn up eua                        # liga (lembra país e caminho)
    ./vpn pais japao                    # troca de país, sem reiniciar o Tor
    ./vpn up --so-tor [--saida de]      # Só Tor; --saida fixa o país de saída
    ./vpn status                        # estado, IP e caminho conferido
    ./vpn celular                       # chave e QR code para o Outline
    ./vpn down                          # desliga

Testes: `/bin/bash tests/run.sh` e `cd app && swift test`.

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
- **Identidade:** o Proton só não vê seu IP se a conta for usada **exclusivamente pelo Tor** (cadastro, painel e conexões). Sem Só Proton com essa conta, sem abrir o painel num navegador comum.
- **O que o celular entrega por si só:** fuso horário, idioma, GPS e contas logadas continuam dizendo quem e onde você está. IPv6 do celular não foi testado.
- Streaming (Netflix etc.) costuma bloquear IPs de VPN grátis. Modo Tor é lento (~95 KB/s).

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `Sem arquivo .ovpn de <país>` | Baixe o .ovpn TCP grátis desse país no painel (pelo Tor Browser) e importe. |
| Modo `--tor` não conecta | O circuito do Tor pode estar ruim: rode o mesmo comando de novo (sorteia outro servidor). |
| `A rede do Mac mudou: VPN desligada` | Normal ao trocar de Wi-Fi. Rode `./vpn up` de novo e, se o IP do Mac mudou, atualize a chave no Outline (`./vpn celular`). |
| `Conexão fora do Tor detectada` | Algo tentou falar com o Proton sem o Tor; tudo foi desligado. Rode `./vpn up` de novo; se repetir, troque o arquivo .ovpn daquele país. |
| `O túnel não conectou` | Tente de novo ou outro país. |
| Celular conecta mas não navega | `./vpn status`; se o IP do Mac mudou, `./vpn celular` e troque a chave no Outline. |
| `Outro aparelho já usa sua conta` | O plano grátis permite 1 conexão: desconecte o outro. |
| `./vpn logs` | Log do túnel, ao vivo. |
