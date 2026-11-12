# Outis

A per-country VPN for your phone, running on your Mac. *Outis* means "Nobody" in Greek: the name Odysseus gives the Cyclops.

Your phone connects to your Mac with the **Outline** app and reaches the internet from another country, through **Tor** and **ProtonVPN Free** running on the Mac. The Mac itself can also browse through Tor.

> The app and the command line are in Brazilian Portuguese.

## At a glance

| | |
|---|---|
| Platform | macOS 14 or newer, Apple Silicon and Intel (only tested on macOS 27) |
| Interface | Window app plus a menu bar icon, with a full command line (`vpn`) embedded in it |
| Phone app | [Outline](https://getoutline.org) (iPhone and Android), connected over Shadowsocks on port 8388 |
| Requirements | `tor` from Homebrew for the This Mac route (installed automatically); [OrbStack](https://orbstack.dev) for the phone route; [Tor Browser](https://www.torproject.org) to create and manage the Proton account |
| VPN provider | ProtonVPN Free, over OpenVPN TCP |
| Free countries | United States, Canada, Mexico, Netherlands, Switzerland, Norway, Poland, Romania, Japan, Singapore |
| Data | `~/Library/Application Support/vpn-pais`; OpenVPN credentials in the Keychain |
| Speed | Slow in the default path: about 95 KB/s and 4 s per page (measured on 2026-11-03) |

## Install

With [Homebrew](https://brew.sh) (this repository is its own tap):

    brew tap mouramateus/outis https://github.com/mouramateus/outis
    brew install --cask mouramateus/outis/outis

Or from a clone of the repository:

    git clone https://github.com/mouramateus/outis.git
    cd outis
    ./install.sh

Both put `Outis.app` in `/Applications`, add an `outis` command and install `tor` and `qrencode` from Homebrew. The app is ad-hoc signed, not notarized by Apple: both installers clear the quarantine flag so macOS opens it. If you download the zip from Releases by hand, run `xattr -dr com.apple.quarantine /Applications/Outis.app` once.

Then install the requirements and open the app:

    brew install --cask orbstack tor-browser

On first launch, allow notifications: Outis uses them to tell you when it shut the VPN down.

To uninstall: `brew uninstall --cask outis` (add `--zap` to also delete your data and credentials folder).

## How it works

Three paths for the phone:

    Tor + VPN (default):     phone (Outline) ─▶ Mac :8388 ─▶ Tor ─OpenVPN TCP─▶ Proton ─▶ internet
    Tor only (experimental): phone (Outline) ─▶ Mac :8388 ─▶ Tor ─▶ internet
    VPN only:                phone (Outline) ─▶ Mac :8388 ─▶ Proton ─▶ internet

- **Tor + VPN** is the default. Proton only ever sees a Tor exit node, never your home IP, and websites see a Proton IP in the country you picked.
- **Tor only** needs no account and lets you pin the exit country. It has no UDP, so it stays experimental until tested with Outline on a real iPhone.
- **VPN only** breaks the account's anonymity for good: Proton sees your home IP. It requires typing a confirmation, applies to one connection only and is never saved.

### Two routes

- **Phone route:** the chain above, in containers on OrbStack ([gluetun](https://github.com/qdm12/gluetun), Tor and [gost](https://github.com/go-gost/gost)).
- **This Mac route** ("Este Mac" tab): native Tor (Homebrew's `tor`, or Tor Browser's as a fallback) plus the system SOCKS proxy, with no OrbStack and no Proton account. It only covers apps that honor the system proxy: browsers do; Terminal, Docker, Mail, calls and games do not. The proxy is only turned on after Tor proves it works. If Tor dies, the proxy stays on on purpose: browsers lose internet instead of leaking your home IP, and the app offers to restart or turn it off.

On the home screen and in the menu bar, the **Celular · Este Mac · Os dois** (Phone · This Mac · Both) selector sets what the on/off button controls, and the button always says what it is about to do. While an action runs, the app shows which one, even if it came from the terminal.

If OrbStack is set to `network_proxy: auto`, the system proxy cuts the containers off the internet, so the two routes cannot run together: Outis warns which one will drop and asks for confirmation. With `orb config set network_proxy none` they coexist and the warning disappears. That setting applies to all of OrbStack.

Closing the window or quitting (⌘Q) does **not** turn the VPN off.

## The app

| Tab | What it does |
|---|---|
| Início (Home) | Status, exit country and IP on a world map, route selector and the on/off button |
| Celular (Phone) | Outline access key and QR code, the Mac's IP and network, how to connect, active phone connections |
| Este Mac (This Mac) | Turns the This Mac route on and off, with an optional exit country |
| Conta (Account) | Stores the OpenVPN credentials in the Keychain and imports the `.ovpn` files |
| Avançado (Advanced) | Phone path (Tor + VPN, Tor only, or VPN only after typing `ENTENDO`), exit country for Tor only, phone port and network-change behavior |
| Logs | Live tunnel log |

## First setup

1. Create a free Proton account **using Tor Browser only**, and only ever open the Proton dashboard from Tor Browser.
2. In the dashboard, copy the OpenVPN/IKEv2 username and password, and download the free **TCP** `.ovpn` files (GNU/Linux) for the countries you want.
3. In the **Conta** tab (or with `vpn setup-tor`), save the credentials and import the files. By default they are read from `~/Downloads`.
4. Turn the VPN on, open the **Celular** tab and scan the QR code with Outline.

## Command line

The same CLI the app uses. Once installed it is `outis`; from the repository it is `./vpn`; inside the app it lives in `Outis.app/Contents/Resources/cli/vpn`. The examples below use `vpn`.

    vpn init                            # creates the config (phone password)
    vpn setup-tor                       # stores OpenVPN credentials and imports .ovpn files
    vpn importar-ovpn [folders]         # imports free TCP .ovpn files (default: ~/Downloads)
    vpn up eua                          # turns on (remembers country and path)
    vpn pais japao                      # switches country without restarting Tor
    vpn up --so-tor [--saida de]        # Tor only; --saida pins the exit country
    vpn up --so-proton --confirmo-quebrar-anonimato   # VPN only, this connection only
    vpn caminho <tor|sotor>             # picks the path for the next connection
    vpn mac on [--saida de]             # This Mac route through Tor
    vpn mac off                         # turns it off and restores the proxy
    vpn paises [--json]                 # lists the free countries
    vpn status [--json]                 # state, IP and verified path
    vpn celular [--json]                # Outline key and QR code
    vpn conexoes [--json]               # active connections on the phone port
    vpn down                            # turns off
    vpn logs                            # tunnel log

Country names: `eua`, `canada`, `mexico`, `holanda`, `suica`, `noruega`, `polonia`, `romenia`, `japao`, `singapura` (two-letter codes such as `us`, `jp` and `ca` also work).

## What is protected (and what is not)

Protected, verified on 2026-11-03:

- **Kill switch on the Mac side:** if the tunnel drops, phone traffic reaching the Mac does not leave through your home IP. gluetun blocks everything by default, IPv4 and IPv6, with DNS through the tunnel.
- **Tor + VPN checks the path:** on start and every 5 seconds, Outis checks that the connection to Proton only goes through Tor. If a direct connection appears, everything is shut down.
- **Network change shuts everything down:** port 8388 only listens on the Mac's IP in the network where you turned it on. If the network or IP changes (café, office, another Wi-Fi), a watcher brings the VPN down and sends a notification. Nothing turns back on by itself, not even after a reboot.
- **Secrets stay out of `docker inspect`:** credentials and the phone password enter the containers as files (`/run/secrets`), not environment variables.
- **gluetun control panel locked:** anyone with the phone key cannot turn the VPN off through the proxy.
- **Stable Tor:** Tor state lives in a volume, so it keeps the same entry guards and switching countries does not restart it.

**Not** protected:

- **In the phone route, the Mac itself does not go through the VPN.** Only the phone connected through Outline does. Use the This Mac route for the Mac's browsers.
- **The phone has no kill switch of its own.** If the Mac sleeps, the VPN drops or the network changes, the phone falls back to your home connection.
  - Android: Settings → VPN → Outline → turn on "Always-on VPN" and "Block connections without VPN".
  - iPhone: there is no guaranteed block; check the Outline icon before using it.
- **Identity:** Proton only stays blind to your IP if the account is used **exclusively through Tor** (sign-up, dashboard and connections). No VPN only with that account, and never open the dashboard in a regular browser.
- **What the phone gives away on its own:** time zone, language, GPS and logged-in accounts still tell who and where you are. The phone's IPv6 has not been tested.
- Streaming services usually block free VPN IPs.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `Sem arquivo .ovpn de <país>` (no .ovpn for a country) | Download that country's free TCP `.ovpn` from the dashboard (in Tor Browser) and import it. |
| Tor + VPN does not connect | The Tor circuit may be bad: run the same command again (it picks another server). |
| `A rede do Mac mudou: VPN desligada` (network changed) | Expected when you switch Wi-Fi. Turn it on again and, if the Mac's IP changed, update the key in Outline (`vpn celular`). |
| `Conexão fora do Tor detectada` (connection outside Tor) | Something tried to reach Proton without Tor, so everything was shut down. Turn it on again; if it repeats, replace that country's `.ovpn` file. |
| `O túnel não conectou` (tunnel did not connect) | Try again or another country. |
| Phone connects but does not browse | `vpn status`; if the Mac's IP changed, run `vpn celular` and replace the key in Outline. |
| `Outro aparelho já usa sua conta` (another device uses your account) | The free plan allows one connection: disconnect the other device. |

## Development

    ./install.sh --compilar            # builds from source and installs (needs full Xcode)
    app/build.sh [--sem-instalar] [--universal]   # builds the app and embeds the CLI
    scripts/release.sh                 # universal zip for a GitHub Release, plus its sha256 for the cask
    /bin/bash tests/run.sh             # CLI tests (with fake system commands in tests/bin)
    cd app && swift test               # app tests

Layout:

- `vpn`: the CLI (bash 3.2, the version that ships with macOS)
- `compose.yaml`, `tor/`, `config/`: containers for the phone route
- `app/`: the SwiftUI app (`VPNCore` talks to the CLI, `VPNPais` is the interface)
- `install.sh`, `Casks/outis.rb`, `scripts/release.sh`: installer, Homebrew cask (this repository is its own tap) and release packaging
- `docs/`: design spec, plan and approved mockups

## License

MIT, see [LICENSE](LICENSE).

## Fair use and disclaimers

- Proton's Terms of Service forbid holding multiple free accounts and may suspend them. Outis supports one account on purpose.
- Outis is not affiliated with or endorsed by the Tor Project, Proton AG or Jigsaw (Outline).
- Use it within the law and the terms of the services you access.
