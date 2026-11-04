import SwiftUI
import VPNCore

enum Aba: String, CaseIterable, Identifiable {
    case inicio = "Início", celular = "Celular", mac = "Este Mac", conta = "Conta", avancado = "Avançado", logs = "Logs"
    var id: String { rawValue }
    var simbolo: String {
        switch self {
        case .inicio: "globe"
        case .celular: "iphone"
        case .mac: "laptopcomputer"
        case .conta: "person"
        case .avancado: "slider.horizontal.3"
        case .logs: "list.bullet"
        }
    }
}

struct MainView: View {
    let store: StatusStore
    @State private var aba = Aba.inicio

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().overlay(Cor.linha)
            ZStack {
                switch aba {
                case .inicio: InicioView(store: store, aba: $aba)
                case .celular: CelularView(store: store)
                case .mac: EsteMacView(store: store)
                case .conta: ContaView(store: store)
                case .avancado: AvancadoView(store: store)
                case .logs: LogsView(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .frame(minWidth: 960, minHeight: 620)
        .background(Cor.fundo)
        .foregroundStyle(Cor.texto)
        .onAppear { store.janelaAberta = true }
        .onDisappear { store.janelaAberta = false; store.abaCelularAberta = false }
        .onChange(of: aba) { _, nova in
            store.abaCelularAberta = nova == .celular
            if nova == .celular { Task { await store.atualizar() } }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Aba.allCases) { a in
                Button { aba = a } label: {
                    Label(a.rawValue, systemImage: a.simbolo)
                        .font(.system(size: 13.5))
                        .foregroundStyle(a == aba ? Cor.texto : Cor.apagado)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(a == aba ? Color.white.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            cartaoProtecao
        }
        .padding(.top, 44).padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 200)
        .background(Color.white.opacity(0.025))
    }

    private var cartaoProtecao: some View {
        let (titulo, texto) = textoProtecao
        return VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Cor.texto)
            Text(texto).font(.system(size: 12)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .vidro(raio: 12)
    }

    private var textoProtecao: (String, String) {
        if store.atividade == .reconectando { return ("Kill switch ativo", "O túnel está voltando. Nada sai pelo IP de casa.") }
        if let a = store.atividade { return (a.texto, "Aguarde terminar para mudar outra coisa.") }
        guard store.estado == .ligada else {
            return ("Kill switch inativo", store.macEstado == "ligada" ? "Só este Mac está ligado, pelo Tor." : "A VPN está desligada: o celular usa a internet normal.")
        }
        if store.status?.modo == .sotor { return ("Sem saída direta", "Tudo passa pelo Tor.") }
        return ("Kill switch ativo", "Se o túnel cair, o Mac bloqueia a saída pelo IP de casa.")
    }
}
