import AppKit
import SwiftUI
import VPNCore

/// Aviso de que uma rota vai derrubar a outra, com a decisão na mão de quem lê.
struct AvisoConflito: View {
    let store: StatusStore

    var body: some View {
        if let texto = store.confirmacao {
            VStack(alignment: .leading, spacing: 8) {
                Text("⚠︎ \(texto)").font(.system(size: 12.5, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text("O OrbStack segue o proxy do sistema, então as duas rotas não funcionam juntas.")
                    .font(.system(size: 11.5)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Ligar mesmo assim") { Task { await store.confirmar() } }.buttonStyle(BotaoVidro())
                    Button("Cancelar") { store.cancelarConfirmacao() }.buttonStyle(BotaoVidro())
                }
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 1.2))
        }
    }
}

struct EsteMacView: View {
    let store: StatusStore

    private var ligada: Bool { store.macEstado == "ligada" }
    private var desligada: Bool { store.macEstado == "desligada" }
    private var grupos: (incluidos: [String], depende: [String], fora: [String]) {
        AppsDoMac.grupos { nome in
            ["/Applications/\(nome).app", "\(NSHomeDirectory())/Applications/\(nome).app", "/System/Applications/\(nome).app"]
                .contains { FileManager.default.fileExists(atPath: $0) } || nome == "Safari"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                controle
                AvisoConflito(store: store)
                alcance
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.top, 52).padding(.horizontal, 32).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controle: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TituloEstado(texto: tituloEstado, estado: ligada ? .ligado : store.macEstado == "conectando" || store.atividade?.rota == .mac ? .conectando : .parado)
                Spacer()
                Selo(texto: "Só Tor · sem VPN")
            }
            Text(ligada ? "Este Mac pelo Tor" : store.macEstado == "erro" ? "O Tor parou" : "Este Mac fora da VPN")
                .font(.system(size: 26, weight: .semibold))
            Text(descricao).font(.system(size: 13)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
            if desligada {
                HStack {
                    Text("País de saída:").font(.system(size: 12.5)).foregroundStyle(Cor.apagado)
                    Picker("País de saída", selection: Binding(get: { store.saidaMac }, set: { store.saidaMac = $0 })) {
                        Text("Tor escolhe (padrão)").tag("auto")
                        ForEach(store.paises) { p in Text("\(p.bandeira) \(p.nomeCurto)").tag(p.codigo) }
                    }
                    .labelsHidden().frame(width: 220)
                }
                if store.saidaMac != "auto" {
                    Text("Fixar um país restringe os nós de saída: fica um pouco menos anônimo e pode ficar mais lento.")
                        .font(.system(size: 11.5)).foregroundStyle(Cor.apagado)
                }
            }
            HStack(spacing: 10) {
                if desligada {
                    Button("Ligar este Mac") { Task { await store.ligarMac(saida: store.saidaMac) } }.buttonStyle(BotaoPrincipal())
                } else if store.macEstado == "erro" {
                    Button("Religar") { Task { await store.ligarMac(saida: store.status?.macSaida) } }.buttonStyle(BotaoPrincipal())
                    Button("Desligar e voltar ao normal") { Task { await store.desligarMac() } }.buttonStyle(BotaoVidro())
                } else {
                    Spacer()
                    BotaoIcone(simbolo: "power", rotulo: "Desligar este Mac") { Task { await store.desligarMac() } }
                }
            }
            .disabled(store.ocupado)
            if let m = store.mensagem { Text(m).font(.system(size: 12)) }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).vidro(raio: 20)
    }

    private var tituloEstado: String {
        if let a = store.atividade, a.rota == .mac { return a.texto }
        switch store.macEstado {
        case "ligada": return "Ligado"
        case "conectando": return "Conectando"
        case "erro": return "Erro"
        default: return "Desligado"
        }
    }

    private var descricao: String {
        switch store.macEstado {
        case "ligada": "Saída pelo Tor (\(store.status?.macIp ?? "varia")). Muitos sites pedem captcha ou bloqueiam, e fica lento."
        case "erro": "Os apps abaixo estão sem internet, de propósito: sem o Tor, eles sairiam pelo IP de casa."
        default: "Liga o Tor neste Mac, sem OrbStack e sem usar a conta da VPN. Só os apps abaixo passam por ele."
        }
    }

    private var alcance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("O que entra na proteção").font(.system(size: 15, weight: .semibold))
            lista("Incluídos: apps que respeitam o proxy", grupos.incluidos)
            if !grupos.depende.isEmpty {
                lista("Dependem do app: podem ou não respeitar", grupos.depende)
            }
            lista("Fora desta rota: em geral saem pelo IP de casa", grupos.fora)
            Text("Sem kill switch para o que fica de fora. Nas contas logadas, o site continua sabendo quem você é.")
                .font(.system(size: 11.5)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).vidro()
    }

    private func lista(_ titulo: String, _ itens: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo).font(.system(size: 12.5, weight: .semibold))
            Text(itens.joined(separator: " · ")).font(.system(size: 12.5)).foregroundStyle(Cor.apagado)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
