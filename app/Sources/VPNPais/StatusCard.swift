import AppKit
import SwiftUI
import VPNCore

/// Para quem o ligar/desligar aponta: celular, este Mac ou os dois.
struct SeletorAlvo: View {
    let store: StatusStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Alvo.allCases) { a in
                Button { store.alvo = a } label: {
                    Text(a.nome)
                        .font(.system(size: 12, weight: store.alvo == a ? .semibold : .regular))
                        .foregroundStyle(store.alvo == a ? Cor.texto : Cor.apagado)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .background(store.alvo == a ? Color.white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apontar para \(a.nome)")
                .accessibilityAddTraits(store.alvo == a ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Cor.linha))
        .disabled(store.ocupado)
    }
}

/// Uma linha por rota: o que está no ar e o que está mudando agora.
struct LinhaRota: View {
    let store: StatusStore
    let rota: Rota

    private var mudando: Atividade? { store.atividade?.rota == rota ? store.atividade : nil }

    private var texto: String {
        if let mudando { return mudando.texto + "…" }
        if rota == .mac {
            switch store.macEstado {
            case "ligada": return "Este Mac: pelo Tor (\(store.status?.macIp ?? "varia"))"
            case "conectando": return "Este Mac: conectando…"
            case "erro": return "Este Mac: o Tor parou, apps sem internet"
            default: return "Este Mac: desligado"
            }
        }
        switch store.estado {
        case .ligada:
            if store.status?.modo == .sotor { return "Celular: pelo Tor" }
            return "Celular: \(store.paisAtual?.nomeCurto ?? "ligado")"
        case .conectando: return "Celular: conectando…"
        case .erro: return "Celular: erro"
        case .desligada: return "Celular: desligado"
        }
    }

    private var visual: EstadoVisual {
        if mudando != nil { return .conectando }
        let ligada = rota == .mac ? store.macEstado == "ligada" : store.estado == .ligada
        let indo = rota == .mac ? store.macEstado == "conectando" : store.estado == .conectando
        return ligada ? .ligado : indo ? .conectando : .parado
    }

    var body: some View {
        HStack(spacing: 8) {
            PontoEstado(estado: visual).id(visual)
            Text(texto).font(.system(size: 12.5)).foregroundStyle(visual == .parado ? Cor.apagado : Cor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StatusCard: View {
    let store: StatusStore
    @Binding var aba: Aba

    private var s: Status? { store.status }
    private var modo: Caminho { s?.modo ?? .tor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SeletorAlvo(store: store).padding(.bottom, 14)
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
        if let a = store.atividade {
            emAndamento(a)
        } else if s?.aviso == "orbstack", store.alvo != .mac {
            parado("OrbStack fechado", "O celular precisa do OrbStack. A rota deste Mac funciona sem ele.", "Abrir OrbStack") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/OrbStack.app"))
            }
        } else if s?.ipMac == nil, store.alvo != .mac, store.estado == .desligada {
            informativo("Sem rede", "Conecte o Mac a uma rede para ligar a rota do celular.")
        } else if store.macEstado == "erro", store.alvo != .celular {
            parado("O Tor parou", "Os apps deste Mac estão sem internet, de propósito, para não sair pelo IP de casa.", "Ver opções", estadoTitulo: "Erro") { aba = .mac }
        } else if store.estado == .ligada {
            ligada
        } else if store.estado == .erro, store.alvo != .mac {
            erro
        } else if let cod = s?.motivoCodigo, let motivo = s?.motivo, store.alvo != .mac {
            caiu(cod, motivo)
        } else if store.macEstado == "ligada" {
            macLigado
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

    /// Ligar o que falta no alvo e desligar o que está ativo, sempre dizendo o quê.
    private var acoes: some View {
        HStack(spacing: 10) {
            if let p = store.paisSelecionado, modo != .sotor, store.estado == .ligada {
                Button {
                    Task { await store.conectarSelecionado() }
                } label: {
                    Text("Conectar em \(p.nomeCurto) ").fontWeight(.semibold) + Text("· ~2 min").fontWeight(.regular)
                }
                .buttonStyle(BotaoPrincipal())
            } else if !store.faltam.isEmpty {
                Button(store.rotuloLigar) { Task { await store.ligarAlvo() } }.buttonStyle(BotaoPrincipal())
            } else {
                Text(store.rotuloDesligar).font(.system(size: 12.5)).foregroundStyle(Cor.apagado)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !store.ativas.isEmpty {
                BotaoIcone(simbolo: "power", rotulo: store.rotuloDesligar) { Task { await store.desligarAlvo() } }
            }
        }
        .padding(.top, 14)
        .disabled(store.ocupado)
    }

    private var ligada: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { TituloEstado(texto: "Ligada", estado: .ligado); Spacer(); Selo(texto: seloCaminho) }
            Text(nomePais).font(.system(size: 28, weight: .semibold)).padding(.top, 12)
            Text(linhaIp).font(.system(size: 13.5).monospacedDigit()).foregroundStyle(Cor.apagado).padding(.top, 3)
            if modo == .proton {
                Text("Só Proton: o Proton vê seu IP").font(.system(size: 12, weight: .semibold)).padding(.top, 8)
            }
            if s?.aviso == "pais_diferente", let p = s?.paisIp {
                Text("O Proton localiza este IP em \(p).").font(.system(size: 12)).foregroundStyle(Cor.apagado).padding(.top, 6)
            }
            rota.padding(.top, 12)
            LinhaRota(store: store, rota: .mac).padding(.top, 10)
            acoes
        }
    }

    private var macLigado: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { TituloEstado(texto: "Ligado", estado: .ligado); Spacer(); Selo(texto: "Só Tor") }
            Text("Este Mac").font(.system(size: 28, weight: .semibold)).padding(.top, 12)
            Text("\(s?.macIp ?? "Saída pelo Tor") · só apps que respeitam o proxy").font(.system(size: 13)).foregroundStyle(Cor.apagado).padding(.top, 3)
            LinhaRota(store: store, rota: .celular).padding(.top, 10)
            acoes
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

    /// Qualquer ação em curso: diz o que está acontecendo, há quanto tempo e o que dá para fazer.
    private func emAndamento(_ a: Atividade) -> some View {
        let ligando: Bool
        if case .ligando = a { ligando = true } else { ligando = false }
        return VStack(alignment: .leading, spacing: 0) {
            TituloEstado(texto: a.texto, estado: .conectando).id(a.texto)
            if ligando, a.rota == .celular {
                Text(nomePais).font(.system(size: 24, weight: .semibold)).padding(.top, 12)
            }
            if ligando {
                VStack(alignment: .leading, spacing: 5) {
                    if a.rota == .mac {
                        linhaEtapa("Tor conectado", "Conectando ao Tor", .tor)
                        linhaEtapa("Saída conferida", "Conferindo a saída", .conferindo)
                    } else {
                        if modo != .proton { linhaEtapa("Tor conectado", "Conectando ao Tor", .tor) }
                        if modo != .sotor {
                            linhaEtapa("Proton conectado", "Conectando ao Proton", .proton)
                            linhaEtapa("Caminho e IP conferidos", "Conferindo caminho e IP", .conferindo)
                        }
                    }
                }
                .padding(.top, 10)
            } else {
                Text(detalhe(a)).font(.system(size: 12.5)).foregroundStyle(Cor.apagado).padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let i = store.inicioConexao {
                TimelineView(.periodic(from: .now, by: 1)) { t in
                    let seg = max(0, Int(t.date.timeIntervalSince(i)))
                    Text(String(format: "%d:%02d", seg / 60, seg % 60) + (ligando ? " · costuma levar até 2 min" : ""))
                        .font(.system(size: 13).monospacedDigit()).foregroundStyle(Cor.apagado)
                }
                .padding(.top, 10)
            }
            LinhaRota(store: store, rota: a.rota == .mac ? .celular : .mac).padding(.top, 10)
            if ligando, store.acaoEmAndamento {
                Button("Cancelar") { store.cancelar() }.buttonStyle(BotaoVidro()).padding(.top, 12)
            }
        }
    }

    private func detalhe(_ a: Atividade) -> String {
        switch a {
        case .desligando(.celular): "Parando o túnel. O iPhone fica sem VPN ao terminar."
        case .desligando(.mac): "Parando o Tor e restaurando o proxy do sistema."
        case .cancelando: "Interrompendo e limpando o que já tinha subido."
        case .reconectando: "O túnel saiu do ar e está voltando sozinho. Nada sai pelo IP de casa."
        case .ligando: ""
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

    private var tituloDesligada: String {
        switch store.alvo {
        case .celular: modo == .sotor ? "Só Tor" : store.paisSelecionado?.nomePT ?? store.paisAtual?.nomePT ?? nomePais
        case .mac: "Este Mac"
        case .ambos: "Celular e este Mac"
        }
    }

    private var textoDesligada: String {
        switch store.alvo {
        case .celular: modo == .sotor ? "O iPhone sai direto pelo Tor." : store.paisSelecionado == nil ? "Último país usado. O iPhone está sem VPN." : "Pronto para conectar."
        case .mac: "Só apps que respeitam o proxy. Veja a lista na aba Este Mac."
        case .ambos: "O iPhone pela VPN e este Mac pelo Tor."
        }
    }

    private var desligada: some View {
        parado(tituloDesligada, textoDesligada, botaoDesligada) {
            Task {
                if store.paisSelecionado != nil, store.alvo == .celular { await store.conectarSelecionado() } else { await store.ligarAlvo() }
            }
        }
    }

    private var botaoDesligada: String {
        guard store.alvo == .celular, modo != .sotor else { return store.rotuloLigar }
        return "Ligar celular em \((store.paisSelecionado ?? store.paisAtual)?.nomeCurto ?? "…")"
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

    private func informativo(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloEstado(texto: "Desligada", estado: .parado)
            Text(titulo).font(.system(size: 24, weight: .semibold)).padding(.top, 12)
            Text(texto).font(.system(size: 12.5)).foregroundStyle(Cor.apagado).padding(.top, 5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func parado(_ titulo: String, _ texto: String, _ botao: String, nota: String? = nil, estadoTitulo: String = "Desligada",
                        acao: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloEstado(texto: estadoTitulo, estado: .parado)
            Text(titulo).font(.system(size: 24, weight: .semibold)).padding(.top, 12)
            Text(texto).font(.system(size: 12.5)).foregroundStyle(Cor.apagado).padding(.top, 5)
                .fixedSize(horizontal: false, vertical: true)
            if store.alvo != .celular || store.macEstado != "desligada" {
                LinhaRota(store: store, rota: .mac).padding(.top, 10)
            }
            Button(botao, action: acao).buttonStyle(BotaoPrincipal()).padding(.top, 14).disabled(store.ocupado)
            if !store.ativas.isEmpty {
                HStack {
                    Spacer()
                    Button(store.rotuloDesligar) { Task { await store.desligarAlvo() } }.buttonStyle(BotaoVidro())
                }
                .padding(.top, 8).disabled(store.ocupado)
            }
            if let nota {
                Text(nota).font(.system(size: 11.5)).foregroundStyle(Cor.apagado).padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
