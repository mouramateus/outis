import AppKit
import SwiftUI
import VPNCore

/// URLs do Proton abrem sempre no Tor Browser, nunca no navegador padrão: a conta só existe pelo Tor.
@MainActor func abrirNoTor(_ endereco: String, store: StatusStore) {
    let app = URL(fileURLWithPath: "/Applications/Tor Browser.app")
    guard let url = URL(string: endereco), FileManager.default.fileExists(atPath: app.path) else {
        store.mensagem = "Instale o Tor Browser (torproject.org): a conta da VPN só deve ser aberta por ele."
        return
    }
    NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
}

@MainActor func escolherPastas() -> [URL] {
    let p = NSOpenPanel()
    p.canChooseDirectories = true
    p.canChooseFiles = false
    p.allowsMultipleSelection = true
    p.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    p.prompt = "Importar"
    return p.runModal() == .OK ? p.urls : []
}

struct ContaView: View {
    let store: StatusStore
    @State private var usuario = ""
    @State private var senha = ""
    @State private var trocando = false
    @State private var aviso: String?

    private var totalOvpn: Int { store.paises.reduce(0) { $0 + $1.ovpn } }
    private var temCredenciais: Bool { store.status?.credenciais == true }
    private var falta: Bool { !temCredenciais || totalOvpn == 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if falta { assistente } else { resumo }
                if trocando { formulario }
                if let t = aviso ?? store.mensagem { Text(t).font(.system(size: 12.5)).foregroundStyle(Cor.apagado) }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.top, 56).padding(.horizontal, 36).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resumo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Conta da VPN").font(.system(size: 16, weight: .semibold)); Spacer(); Selo(texto: "✓ credenciais salvas") }
            Text("Provedor: ProtonVPN (plano grátis). Conta usada só pelo Tor: abra o painel apenas pelo Tor Browser.")
                .font(.system(size: 13)).foregroundStyle(Cor.apagado)
            etiquetas
            Text("Arquivos .ovpn por país").font(.system(size: 11.5)).foregroundStyle(Cor.apagado)
            HStack(spacing: 8) {
                Button("Trocar credenciais") { trocando.toggle() }.buttonStyle(BotaoVidro())
                importar
                Button("Painel do provedor (Tor Browser) ↗") { abrirNoTor("https://account.protonvpn.com/account", store: store) }.buttonStyle(BotaoVidro())
            }
            .padding(.top, 8)
        }
        .padding(24).vidro()
    }

    private var etiquetas: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 6), count: 10), alignment: .leading, spacing: 6) {
            ForEach(store.paises) { p in
                Text("\(p.bandeira) \(p.ovpn)").font(.system(size: 11.5)).fixedSize()
                    .foregroundStyle(p.ovpn == 0 ? Cor.apagado : Cor.texto)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(Cor.linha, style: StrokeStyle(lineWidth: 1, dash: p.ovpn == 0 ? [3, 2] : [])))
                    .accessibilityLabel("\(p.nomePT): \(p.ovpn) arquivos")
            }
        }
    }

    private var importar: some View {
        Button("Importar .ovpn…") {
            let pastas = escolherPastas()
            guard !pastas.isEmpty else { return }
            Task {
                do {
                    let i = try await store.importar(pastas: pastas)
                    aviso = "\(i.importados) arquivos importados" + (i.recusados > 0 ? ", \(i.recusados) recusados." : ".")
                } catch { aviso = "Não consegui importar." }
            }
        }
        .buttonStyle(BotaoVidro())
    }

    private var assistente: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuração").font(.system(size: 16, weight: .semibold))
            passo(1, "Conta pelo Tor", feito: temCredenciais, "Crie a conta Free pelo Tor Browser e baixe os arquivos em Downloads → OpenVPN (GNU/Linux, TCP, servidores grátis).") {
                HStack {
                    Button("Criar conta ↗") { abrirNoTor("https://account.protonvpn.com/signup", store: store) }.buttonStyle(BotaoVidro())
                    Button("Downloads ↗") { abrirNoTor("https://account.protonvpn.com/downloads", store: store) }.buttonStyle(BotaoVidro())
                }
            }
            passo(2, "Credenciais OpenVPN", feito: temCredenciais, "Não é o login da conta: fica em Conta → Nome de usuário OpenVPN / IKEv2.") {
                if !temCredenciais { formulario }
            }
            passo(3, "Arquivos .ovpn", feito: totalOvpn > 0, "Importe da pasta Downloads.") { importar }
        }
        .padding(24).vidro()
    }

    private func passo<V: View>(_ n: Int, _ titulo: String, feito: Bool, _ texto: String, @ViewBuilder _ conteudo: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(feito ? "\(n) ✓  \(titulo)" : "\(n)  \(titulo)").font(.system(size: 13.5, weight: .semibold))
            Text(texto).font(.system(size: 12.5)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
            conteudo()
        }
    }

    private var formulario: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Usuário OpenVPN", text: $usuario).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            SecureField("Senha OpenVPN", text: $senha).textFieldStyle(.roundedBorder)
            Button("Salvar no Keychain") {
                Task {
                    do {
                        try await store.salvarCredenciais(usuario: usuario, senha: senha)
                        usuario = ""; senha = ""; trocando = false; aviso = "Credenciais salvas."
                    } catch { aviso = "Não consegui salvar. Preencha usuário e senha." }
                }
            }
            .buttonStyle(BotaoVidro())
        }
        .frame(maxWidth: 360)
    }
}
