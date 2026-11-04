import AppKit
import SwiftUI
import VPNCore

struct MenuRapidoView: View {
    let store: StatusStore
    @Environment(\.openWindow) private var abrirJanela

    private var soTor: Bool { store.status?.modo == .sotor }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                TituloEstado(texto: tituloEstado, estado: visual)
                Text(soTor ? "Só Tor" : store.paisAtual?.nomePT ?? "—").font(.system(size: 17, weight: .semibold)).padding(.top, 4)
                Text(linha).font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Cor.apagado)
                if store.macEstado == "ligada" {
                    Text("Este Mac: pelo Tor").font(.system(size: 12)).foregroundStyle(Cor.apagado)
                }
                if store.status?.modo == .proton && store.estado == .ligada {
                    Text("Só Proton: o Proton vê seu IP").font(.system(size: 12, weight: .semibold))
                }
            }
            HStack(spacing: 10) {
                if !soTor {
                    Picker("País", selection: Binding(
                        get: { store.selecionado ?? store.status?.codigo ?? "" },
                        set: { store.selecionar($0) })) {
                        ForEach(store.paises.filter { $0.ovpn > 0 }) { p in Text("\(p.bandeira) \(p.nomeCurto)").tag(p.codigo) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                } else {
                    Spacer()
                }
                BotaoIcone(simbolo: "power", rotulo: store.estado == .desligada ? "Ligar" : "Desligar", tamanho: 36) {
                    Task {
                        if store.estado == .desligada || store.estado == .erro { await store.ligar() } else { await store.desligar() }
                    }
                }
                BotaoIcone(simbolo: "macwindow", rotulo: "Abrir o app", claro: false, tamanho: 36) {
                    NSApp.activate(ignoringOtherApps: true)
                    abrirJanela(id: "principal")
                }
            }
            .disabled(store.ocupado)
            AvisoConflito(store: store)
            if let p = store.paisSelecionado {
                Button("Conectar em \(p.nomeCurto) · ~2 min") { Task { await store.conectarSelecionado() } }
                    .buttonStyle(BotaoPrincipal())
                    .disabled(store.ocupado)
            }
        }
        .padding(16)
        .frame(width: 290)
        .background(Cor.fundo.opacity(0.4))
        .foregroundStyle(Cor.texto)
    }

    private var visual: EstadoVisual {
        store.estado == .ligada ? .ligado : store.estado == .conectando || store.ocupado ? .conectando : .parado
    }

    private var tituloEstado: String {
        let caminho = soTor ? "Só Tor" : store.status?.modo == .proton ? "Só Proton" : "Tor + Proton"
        switch store.estado {
        case .ligada: return "Ligada · \(caminho)"
        case .conectando: return "Conectando"
        case .erro: return "Erro"
        case .desligada: return "Desligada"
        }
    }

    private var linha: String {
        if store.estado == .ligada {
            return soTor ? "Saída pelo Tor (varia)" : [store.status?.ipSaida, store.status?.cidade].compactMap { $0 }.joined(separator: " · ")
        }
        return store.status?.aviso == "orbstack" ? "OrbStack fechado" : store.status?.motivo ?? "O iPhone está sem VPN"
    }
}
