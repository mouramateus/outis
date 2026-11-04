# App desktop do vpn-pais — design (v2)

Data: 2026-11-03. Revisado depois do party mode e das revisões de segurança e adversarial.
Visual aprovado: `docs/superpowers/mockups/app-aprovado.html` (versão v4 dos mockups).

## Intenção

Um app de Mac que faz, sem terminal, tudo o que o `./vpn` faz: ligar Tor + VPN, trocar país, gerir a conta do Proton, conectar o celular e ver o IP do Mac na rede atual, com um ícone de estado na barra de menus. Pedido do dono: o mais barato e simples possível, bonito, em vidro a partir do preto e em escala de cinza. O celular do dono é um **iPhone**.

## Objetivos

1. Janela com sidebar com ícones: Início · Celular · Conta · Avançado · Logs.
2. Ícone na barra de menus com menu mínimo.
3. Aba Conta como resumo; assistente de 3 passos só quando falta algo.
4. Aba Celular com QR, chave, rede do Mac, conexões ativas e aviso do iPhone.
5. Aba Avançado com os 3 caminhos.
6. Compatível com macOS 14 ou mais novo, Apple Silicon e Intel.

## Não-objetivos

Assinatura Apple/notarização, App Store, atualização automática, abrir ao iniciar o Mac (decisão do dono: não), app de celular, relés reais do Tor no mapa, outros provedores, modo WireGuard (removido: o dono nunca usará).

## Antiobjetivos

- Dizer "Ligada" sem o IP de saída confirmado e, nos caminhos com Tor + Proton, sem o caminho pelo Tor conferido.
- Prometer proteção que não existe. O iPhone não tem kill switch: o aviso fica na aba Celular e na notificação de queda.
- Duplicar lógica: o app só chama o `./vpn`. Regra de estado fica só no CLI.
- Paleta fora de preto, cinzas e branco; texto com contraste abaixo de 4,5:1.

## Decisões do dono

- **Tela inicial (Início):** mapa-múndi da v1 ocupando a tela. Países com rótulo; o atual brilha; clicar num país só **seleciona** (anel tracejado, "· selecionado"), e o cartão oferece "Conectar em Japão · ~2 min". País sem `.ovpn` fica tracejado, com "sem .ovpn", e não é selecionável; clicar explica o motivo. Área de clique de pelo menos 24 pt. Chip no topo com IP do Mac, Wi-Fi/Cabo e nº de conexões; legenda no canto.
- **Cartão do canto:** estado, selo "✓ Tor + Proton conferido", país, IP · cidade · "conferido há N min", rota iPhone — Mac — Tor ×3 — Proton XX — internet, botão Conectar quando há seleção e botão **⏻ só com ícone** para desligar. Estados: desligada ("Ligar em EUA"), conectando (etapas ✓/●/○, cronômetro, "costuma levar até 2 min", Cancelar), rede mudou ("Religar nesta rede" e lembrete do Outline), erro específico com a sua ação, OrbStack fechado ("Abrir OrbStack").
- **Caminho do Tor no mapa é simulação:** linha seu Mac → 3 países sorteados entre os que têm `.ovpn` (sem repetir, sem o atual) → país atual, com anel nos sorteados e legenda "Tor ×3 (simulação)". Sorteia a cada conexão e a cada 10 min. Só aparece quando ligada. "Reduzir movimento" para a animação.
- **Sidebar:** cartão "Kill switch ativo — Se o túnel cair, o Mac bloqueia a saída pelo IP de casa." quando ligada; "Kill switch inativo" quando desligada.
- **Barra de menus:** globo monocromático adaptável (cheio + sigla do país = ligada; progresso = conectando; contornado = desligada; com "!" = erro). Menu: estado, país, IP, seletor de país, ⏻ e ícone para abrir o app. Nada mais. Sair: ⌘Q com a janela aberta; **sair não desliga a VPN**.
- **Celular:** QR grande, Copiar chave, instruções do Outline, IP e rede, aviso do iPhone, "Conexões ativas" (conexão fica listada por 3 min após a última atividade; são conexões, não aparelhos verificados).
- **Conta:** resumo (credenciais salvas, `.ovpn` por país, Trocar credenciais, Importar .ovpn…, Painel do Proton pelo Tor Browser). Sempre abre URLs do Proton no Tor Browser, nunca no navegador padrão.
- **Avançado:** caminho do celular: **Tor + Proton** (padrão), **Só Tor** (sem conta; país de saída: "Tor escolhe" por padrão, ou um país, com aviso de menos anonimato), **Só Proton** (aviso forte; só ativa digitando ENTENDO, porque o Proton vê o IP de casa ligado à conta para sempre). Porta do celular. "Ao trocar de rede: desliga tudo" é fixo.
- **Rede mudou:** tudo cai. Notificação "A rede mudou: VPN desligada. Seu iPhone pode estar sem VPN." com botão "Religar nesta rede". Nunca religa sozinho.
- **Segredos:** dados no disco interno (`~/Library/Application Support/vpn-pais`). Credenciais OpenVPN no Keychain, leitura sem pedir senha (decisão do dono), sempre via CLI.

## Como (chamadas minhas)

- **SwiftUI nativo**, pacote em `app/`, alvo macOS 14; `glassEffect` com `#available(macOS 26, *)` e `.ultraThinMaterial` antes disso. `app/build.sh` gera binário universal, monta `VPN País.app`, assina ad-hoc e instala em `/Applications`.
- **O app embute o código do CLI** (`vpn`, composes, `tor/`, `config/`) em `Contents/Resources`, e não depende do SSD. Isso também evita rodar um script de um disco externo que pode ser trocado.
- **CLI sem `jq`** (macOS 13 e 14 não trazem) e compatível com bash 3.2.
- **Contrato JSON** em `./vpn status --json`, que nunca falha nem abre o OrbStack; `paises`, `celular`, `conexoes` com `--json`; `init`, `escolher`, `importar-ovpn <pastas>`, `credenciais-openvpn` (stdin), `migrar-keychain`, `caminho <tor|sotor|proton> [--pais xx] [--confirmo-quebrar-anonimato]`.
- **Estado:** `erro` só vale com a VPN parada: túnel saudável vence. IP de saída vem do `PUBLICIP` do gluetun (uma vez por conexão) lido no painel local. Só Tor não tem IP fixo: mostra "saída pelo Tor (varia)".
- **Só Tor:** container `gost` recebe o Shadowsocks e encaminha tudo ao SOCKS do Tor. Sem UDP: comportamento do Outline nesse caminho precisa de teste no iPhone.
- **Ações:** uma por vez (trava com liberação por `trap`), exposta como `operacao` no status. Etapas impressas como `etapa: tor|proton|conferindo`. Cancelar encerra a ação e roda `down`. Timeout do app: 480 s, acima do pior caso do CLI.
- **Atualização:** 5 s com a janela aberta ou conectando, 30 s fora disso; refresh ao acordar (`didWakeNotification`); conexões só com a aba Celular aberta.
- **Testes de verificação nunca tocam o ambiente real:** `VPN_DATA`, `VPN_KC_SERVICE`, `VPN_PROJECT` e `SS_PORT` configuráveis.

## Regras definidas depois da revisão (chamadas minhas, sempre pelo lado seguro)

- **Só Proton nunca é testado com a conta real.** Verificação só por stubs e inspeção da configuração gerada, sem nenhuma conexão ao Proton.
- **Seleção é só da interface.** O `.env` guarda o caminho e o país ativos (ou os próximos, com a VPN desligada). Com a VPN ligada, trocar país ou caminho sempre passa por um botão explícito que reconecta. No menu da barra, escolher outro país revela "Conectar em X"; sem isso, nada acontece.
- **O ENTENDO vale para uma conexão só.** Só Proton não fica salvo: depois de desligar, cair ou trocar de rede, o próximo `up` volta a Tor + Proton. "Religar nesta rede" nunca usa Só Proton. Enquanto ligado em Só Proton, o cartão e o menu mostram "Só Proton: o Proton vê seu IP".
- **Só Tor:** o mapa não seleciona país (o país de saída é só no Avançado, com o aviso). A linha simulada termina em "saída do Tor". "Ligada" = Tor em 100% e a porta do celular escutando. Em vez de "Kill switch ativo", o cartão diz "Sem saída direta: tudo passa pelo Tor". Marcado como **experimental** até o dono testar o Outline no iPhone, porque o caminho não tem UDP.
- **Queda sem troca de rede:** com o container de pé e não saudável, o estado é "conectando" (o gluetun tenta sozinho). Depois de 60 s assim, ou se o container parar sem `down`, o vigia derruba tudo, grava o motivo e notifica "A VPN caiu. Seu iPhone pode estar sem VPN." O app mostra a notificação com botão; com o app fechado, vale a notificação simples do vigia.

## Nome e símbolo (decisão do dono)

O app se chama **Outis**. O símbolo é o capuz em pontos que se desfaz para a direita, com estrelas e bruma no rosto: `app/icone-1024.png`, gerado por `docs/superpowers/mockups/simbolo.html`. A barra de menus usa o capuz em pixel art de 16×16. Por dentro, a pasta, o comando `./vpn`, o executável e o identificador continuam com os nomes técnicos.
