# App desktop do vpn-pais — plano de implementação (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App de Mac que controla o `./vpn`, no visual aprovado.

**Architecture:** CLI bash é a única lógica e fala JSON; app SwiftUI só chama o CLI embutido no bundle. `VPNCore` (testável) + executável `VPNPais`.

**Tech Stack:** bash 3.2, `/usr/bin/security`, docker compose; Swift 6, SwiftUI, Swift Testing, CoreImage, UserNotifications.

**Spec:** `docs/superpowers/specs/2026-11-03-app-desktop-design.md` · Visual: `docs/superpowers/mockups/app-aprovado.html`

## Global Constraints

- macOS 14+, arm64 + x86_64; sem dependências externas no app.
- CLI sem `jq`, roda em `/bin/bash` 3.2 (testes podem usar `jq`).
- Paleta preto/cinza/branco; texto ≥ 4,5:1; honrar Reduzir movimento e Reduzir transparência.
- Commits sem `Co-Authored-By` nem rodapé (preferência do dono).
- Testes nunca tocam dados, Keychain, container ou porta reais.

## Review Focus

1. OrbStack fechado ou travado: `status --json` responde em até ~4 s, sem abrir o OrbStack (Task 2).
2. Sem `.env`, sem rede: `status --json` não morre (Task 2).
3. Cancelar ou timeout no meio do `up`: trava liberada, nada a meio (Task 2).
4. Terminal e app ao mesmo tempo: `operacao` no status desabilita controles (Tasks 2 e 5).
5. Aberto pelo Finder: PATH e bundle (Task 4, build cedo).

---

### Task 1: Base do CLI e testes
Files: `vpn`, `tests/{run.sh,lib.sh,bin/*,test_base.sh}`, `compose-tor.yaml`, remover `compose.yaml`, `guardar-credenciais-tor.sh`.
- [ ] Commit inicial do que existe.
- [ ] Harness com stubs (`docker`, `security`, `lsof`, `route`, `ipconfig`, `osascript`), rodando em `/bin/bash`.
- [ ] Testes: Keychain (`credenciais-openvpn`, `migrar-keychain` só apaga após confirmar leitura, falha preserva arquivo), `VPN_KC_SERVICE`/`VPN_PROJECT` isolam, segredo fora do argv (`security -i`).
- [ ] Implementar: remover WireGuard/rápido; `VPN_SOURCED`; Keychain; nomes configuráveis; vigia com `VPN_NOTIFY`.
- [ ] `tests/run.sh` passa; commit.

### Task 2: Caminhos, status e ciclo de vida
Files: `vpn`, `compose-tor.yaml`, `compose-sotor.yaml`, `tor/torrc`, `tests/test_status.sh`.
- [ ] Testes (um por regra): orbstack fechado, travado (stub dorme), sem `.env`, sem rede, parada, conectando, ligada só com IP e caminho, erro não vence túnel saudável, `operacao`, trava liberada em erro e em SIGTERM, código de erro por padrão de log (`AUTH_FAILED`).
- [ ] Implementar `status_json` (sem jq), trava com `trap`, `etapa:`, `erro.json`, PUBLICIP com lista de APIs, modos `tor|sotor|proton`, `caminho`, país de saída do Tor.
- [ ] Verificar ao vivo os 3 caminhos com cliente Shadowsocks; commit.

### Task 3: Comandos do app
Files: `vpn`, `tests/test_comandos.sh`.
- [ ] Testes: `init`, `paises --json`, `celular --json` igual ao texto, `conexoes --json` filtra local, `escolher` não conecta e recusa país sem `.ovpn`, `importar-ovpn` filtra nomes e recusa `.ovpn` com proxy.
- [ ] Implementar; commit.

### Task 4: Pacote Swift, ponte com o CLI e .app
Files: `app/Package.swift`, `app/Sources/VPNCore/{Models,CLI}.swift`, `app/Sources/VPNPais/VPNPaisApp.swift`, `app/build.sh`, `app/Tests/...`.
- [ ] Testes: decodificar status; saída, erro, timeout (mata filhos), stream, chamadas concorrentes (status responde durante stream).
- [ ] Implementar `VPNCLI` não isolado; `build.sh` universal embutindo o CLI, Info.plist com mínimo 14.0.
- [ ] Abrir pelo Finder e ver o status real; commit.

### Task 5: StatusStore
Files: `app/Sources/VPNCore/StatusStore.swift`, testes.
- [ ] Testes: ação única, `operacao` externa bloqueia, cadência, seleção de país, rede mudou, notificação.
- [ ] Implementar; commit.

### Task 6: Tema e Início
Files: `WorldMap.swift`, `Theme.swift`, `MainView.swift`, `InicioView.swift`, `StatusCard.swift`, testes do mapa.
- [ ] Testes: projeção, cidades em terra, sorteio de 3 sem repetir, sem o atual, só países com `.ovpn`.
- [ ] Implementar conforme o mockup; pontos do mapa em imagem única; lista acessível de países para VoiceOver; commit.

### Task 7: Barra de menus
Files: `MenuBarIcon.swift`, `MenuRapidoView.swift`.
- [ ] Implementar; verificar os 4 estados no `.app`; commit.

### Task 8: Celular, Conta, Avançado, Logs
Files: `CelularView.swift`, `QRCode.swift`, `ContaView.swift`, `AvancadoView.swift`, `LogsView.swift`.
- [ ] Implementar conforme o mockup; ENTENDO exato para Só Proton; URLs do Proton sempre no Tor Browser; commit.

### Task 9: Entrega
- [ ] README, ícone do app, `tests/run.sh` e `swift test`, verificação pelo Finder; commit.
