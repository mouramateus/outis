import AppKit
import SwiftUI
import VPNCore

struct StatusCard: View {
    let store: StatusStore
    @Binding var aba: Aba

    private var s: Status? { store.status }
    private var modo: Caminho { s?.modo ?? .tor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            conteudo
            AvisoConflito(store: store).padding(.top, store.confirmacao == nil ? 0 : 10)
            if let m = store.mensagem {
                Text(m).font(.system(size: 12)).foregroundStyle(Cor.texto)
                    .padding(.top, 10).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 372, alignment: .leading)
        .vidro(raio: 20)
    }

    @ViewBuilder private var conteudo: some View {
        if s?.aviso == "orbstack" {
            parado("OrbStack fechado", "O app precisa do OrbStack para ligar a VPN.", "Abrir OrbStack") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/OrbStack.app"))
            }
        } else if store.estado == .conectando || store.acaoEmAndamento {
            conectando
        } else if store.estado == .ligada {
            ligada
        } else if store.estado == .erro {
            erro
        } else if let cod = s?.motivoCodigo, let motivo = s?.motivo {
            caiu(cod, motivo)
        } else {
            desligada
        }
    }

    private var nomePais: String {
        if modo == .sotor { return "Só Tor" }
        return store.paisAtual?.nomePT ?? s?.pais ?? "—"
    }

    private var seloCaminho: String {
        switch modo {
        case .sotor: "Só Tor · experimental"
        case .proton: "Só Proton"
        case .tor: s?.torConferido == true ? "✓ Tor + Proton conferido" : "Tor + Proton"
        }
    }

    private var ligada: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { TituloEstado(texto: "Ligada", estado: .ligado); Spacer(); Selo(texto: seloCaminho) }
            Text(nomePais).font(.system(size: 30, weight: .semibold)).padding(.top, 14)
            Text(linhaIp).font(.system(size: 13.5).monospacedDigit()).foregroundStyle(Cor.apagado).padding(.top, 3)
            if modo == .proton {
                Text("Só Proton: o Proton vê seu IP").font(.system(size: 12, weight: .semibold)).padding(.top, 8)
            }
            if s?.aviso == "pais_diferente", let p = s?.paisIp {
                Text("O Proton localiza este IP em \(p).").font(.system(size: 12)).foregroundStyle(Cor.apagado).padding(.top, 6)
            }
            rota.padding(.top, 14)
            HStack(spacing: 10) {
                if let p = store.paisSelecionado, modo != .sotor {
                    Button {
                        Task { await store.conectarSelecionado() }
                    } label: {
                        Text("Conectar em \(p.nomeCurto) ").fontWeight(.semibold) + Text("· ~2 min").fontWeight(.regular)
                    }
                    .buttonStyle(BotaoPrincipal())
                } else {
                    Spacer()
                }
                BotaoIcone(simbolo: "power", rotulo: "Desligar") { Task { await store.desligar() } }
            }
            .padding(.top, 14)
            .disabled(store.ocupado)
        }
    }

    private var linhaIp: String {
        if modo == .sotor { return "Saída pelo Tor (varia)" }
        let ip = [s?.ipSaida, s?.cidade].compactMap { $0 }.joined(separator: " · ")
        guard let d = s?.desde else { return ip }
        let min = Int(Date().timeIntervalSince(d) / 60)
        return ip + " · ligada há \(min) min"
    }

    private var rota: some View {
        HStack(spacing: 6) {
            pedaco("iPhone", forte: true); fio; pedaco("Mac", forte: true); fio
            if modo != .proton { pedaco("Tor ×3", forte: false); fio }
            if modo != .sotor { pedaco("Proton \(store.paisAtual?.nomeCurto ?? "")", forte: true); fio }
            pedaco("internet", forte: false)
        }
    }

    private var fio: some View { Rectangle().fill(Cor.linhaForte).frame(height: 1).frame(minWidth: 8) }

    private func pedaco(_ t: String, forte: Bool) -> some View {
        Text(t).font(.system(size: 11.5, weight: forte ? .medium : .regular))
            .foregroundStyle(forte ? Cor.texto : Cor.apagado).fixedSize()
    }

    private var conectando: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloEstado(texto: s?.operacao == "down" ? "Desligando" : "Conectando", estado: .conectando)
            Text(nomePais).font(.system(size: 24, weight: .semibold)).padding(.top, 12)
            VStack(alignment: .leading, spacing: 5) {
                if modo != .proton { linhaEtapa("Tor conectado", "Conectando ao Tor", .tor) }
                if modo != .sotor {
                    linhaEtapa("Proton conectado", "Conectando ao Proton", .proton)
                    linhaEtapa("Caminho e IP conferidos", "Conferindo caminho e IP", .conferindo)
                }
            }
            .padding(.top, 10)
            if let i = store.inicioConexao {
                TimelineView(.periodic(from: .now, by: 1)) { t in
                    let seg = max(0, Int(t.date.timeIntervalSince(i)))
                    Text(String(format: "%d:%02d · costuma levar até 2 min", seg / 60, seg % 60))
                        .font(.system(size: 13).monospacedDigit()).foregroundStyle(Cor.apagado)
                }
                .padding(.top, 10)
            }
            if store.acaoEmAndamento {
                Button("Cancelar") { store.cancelar() }.buttonStyle(BotaoVidro()).padding(.top, 12)
            }
        }
    }

    private func linhaEtapa(_ feito: String, _ fazendo: String, _ e: Etapa) -> some View {
        let ordem: [Etapa] = [.tor, .proton, .conferindo]
        let agora = store.etapa.flatMap { ordem.firstIndex(of: $0) } ?? -1
        let minha = ordem.firstIndex(of: e) ?? 0
        let (icone, texto, cor, peso): (String, String, Color, Font.Weight) =
            minha < agora ? ("checkmark", feito, Cor.texto, .regular)
            : minha == agora ? ("circle.fill", fazendo, .white, .semibold)
            : ("circle", fazendo, Cor.apagado, .regular)
        return HStack(spacing: 8) {
            Image(systemName: icone).font(.system(size: 9, weight: .bold)).frame(width: 12)
            Text(texto).font(.system(size: 12.5, weight: peso))
        }
        .foregroundStyle(cor)
    }

    private var desligada: some View {
        parado(store.paisAtual?.nomePT ?? nomePais,
               store.paisSelecionado == nil ? "Último país usado. O iPhone está sem VPN." : "Pronto para conectar.",
               "Ligar em \((store.paisSelecionado ?? store.paisAtual)?.nomeCurto ?? "…")") {
            Task {
                if store.paisSelecionado != nil { await store.conectarSelecionado() } else { await store.ligar() }
            }
        }
    }

    private func caiu(_ codigo: String, _ motivo: String) -> some View {
        parado(codigo == "rede" ? "A rede do Mac mudou" : "A VPN caiu", motivo, "Religar nesta rede",
               nota: store.redeMudou ? "Depois de religar, atualize a chave no Outline (o IP do Mac mudou)." : nil) {
            Task { await store.ligar() }
        }
    }

    private var erro: some View {
        let cod = s?.codigoErro
        let titulo = cod == "credenciais" ? "Credenciais recusadas" : cod == "limite" ? "Conta em uso" : cod == "tor" ? "O Tor não conectou" : cod == "fora_do_tor" ? "Conexão fora do Tor" : "Não conectou"
        let msg = s?.mensagemErro ?? "Tente de novo."
        if cod == "credenciais" {
            return parado(titulo, msg, "Trocar credenciais", estadoTitulo: "Erro") { aba = .conta }
        }
        return parado(titulo, msg, "Tentar de novo", estadoTitulo: "Erro") { Task { await store.ligar() } }
    }

    private func parado(_ titulo: String, _ texto: String, _ botao: String, nota: String? = nil, estadoTitulo: String = "Desligada",
                        acao: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloEstado(texto: estadoTitulo, estado: .parado)
            Text(titulo).font(.system(size: 24, weight: .semibold)).padding(.top, 12)
            Text(texto).font(.system(size: 12.5)).foregroundStyle(Cor.apagado).padding(.top, 5)
                .fixedSize(horizontal: false, vertical: true)
            Button(botao, action: acao).buttonStyle(BotaoPrincipal()).padding(.top, 14).disabled(store.ocupado)
            if let nota {
                Text(nota).font(.system(size: 11.5)).foregroundStyle(Cor.apagado).padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
