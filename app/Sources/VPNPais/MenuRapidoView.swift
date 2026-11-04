import AppKit
import SwiftUI
import VPNCore

struct MenuRapidoView: View {
    let store: StatusStore
    @Environment(\.openWindow) private var abrirJanela

    private var soTor: Bool { store.status?.modo == .sotor }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                if let a = store.atividade {
                    TituloEstado(texto: a.texto, estado: .conectando).id(a.texto)
                }
                LinhaRota(store: store, rota: .celular)
                LinhaRota(store: store, rota: .mac)
                if store.estado == .ligada, !soTor, let ip = store.status?.ipSaida {
                    Text([ip, store.status?.cidade].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12.5).monospacedDigit()).foregroundStyle(Cor.apagado)
                }
                if store.status?.modo == .proton && store.estado == .ligada {
                    Text("Só VPN: a VPN vê seu IP").font(.system(size: 12, weight: .semibold))
                }
            }
            SeletorAlvo(store: store)
            if store.alvo != .mac, !soTor {
                Picker("País do celular", selection: Binding(
                    get: { store.selecionado ?? store.status?.codigo ?? "" },
                    set: { store.selecionar($0) })) {
                    ForEach(store.paises.filter { $0.ovpn > 0 }) { p in Text("\(p.bandeira) \(p.nomeCurto)").tag(p.codigo) }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .disabled(store.ocupado)
            }
            HStack(spacing: 10) {
                if store.paisSelecionado != nil, store.alvo != .mac, store.estado == .ligada {
                    Button("Conectar em \(store.paisSelecionado?.nomeCurto ?? "")") { Task { await store.conectarSelecionado() } }
                        .buttonStyle(BotaoPrincipal())
                } else if !store.faltam.isEmpty {
                    Button(store.rotuloLigar) { Task { await store.ligarAlvo() } }.buttonStyle(BotaoPrincipal())
                } else {
                    Text(store.rotuloDesligar).font(.system(size: 12.5)).foregroundStyle(Cor.apagado)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if !store.ativas.isEmpty {
                    BotaoIcone(simbolo: "power", rotulo: store.rotuloDesligar, tamanho: 36) { Task { await store.desligarAlvo() } }
                }
                BotaoIcone(simbolo: "macwindow", rotulo: "Abrir o app", claro: false, tamanho: 36) {
                    NSApp.activate(ignoringOtherApps: true)
                    abrirJanela(id: "principal")
                }
            }
            .disabled(store.ocupado)
            AvisoConflito(store: store)
            if let m = store.mensagem { Text(m).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(16)
        .frame(width: 300)
        .background(Cor.fundo.opacity(0.4))
        .foregroundStyle(Cor.texto)
    }
}
