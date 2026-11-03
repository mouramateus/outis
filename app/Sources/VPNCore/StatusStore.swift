import Foundation
import Observation

public struct ConexaoVista: Equatable, Identifiable, Sendable {
    public let ip: String
    public var vistaEm: Date
    public var id: String { ip }
    public func ativa(agora: Date) -> Bool { agora.timeIntervalSince(vistaEm) < 10 }
}

public enum Etapa: String, Sendable { case tor, proton, conferindo }

/// Estado do app. Toda a regra de negócio fica no `./vpn`; aqui só leitura, seleção e ações uma por vez.
@MainActor @Observable public final class StatusStore {
    public private(set) var status: Status?
    public private(set) var paises: [Pais] = []
    public private(set) var celular: Celular?
    public private(set) var conexoes: [ConexaoVista] = []
    public private(set) var selecionado: String?
    public private(set) var etapa: Etapa?
    public private(set) var inicioConexao: Date?
    public private(set) var log: [String] = []
    public private(set) var acaoEmAndamento = false
    public private(set) var redeMudou = false
    public private(set) var ipMacAnterior: String?
    public var mensagem: String?
    public var janelaAberta = false
    public var abaCelularAberta = false

    public var ocupado: Bool { acaoEmAndamento || status?.operacao != nil }
    public var estado: Estado { status?.estado ?? .desligada }
    public var paisAtual: Pais? { paises.first { $0.codigo == status?.codigo } }
    public var paisSelecionado: Pais? { paises.first { $0.codigo == selecionado } }

    private let cli: CLIProtocol
    private let defaults: UserDefaults
    private let notificar: @Sendable (String, String) -> Void
    private var cancelado = false
    private var laco: Task<Void, Never>?

    public init(cli: CLIProtocol, defaults: UserDefaults = .standard,
                notificar: @escaping @Sendable (String, String) -> Void = { _, _ in }) {
        self.cli = cli
        self.defaults = defaults
        self.notificar = notificar
    }

    nonisolated public static func intervalo(janelaAberta: Bool, estado: Estado) -> Int {
        janelaAberta || estado == .conectando ? 5 : 30
    }

    /// Conexão continua na lista por 3 min depois da última atividade.
    nonisolated public static func mesclar(_ vistas: [ConexaoVista], ativas: [Conexao], agora: Date,
                                           graca: TimeInterval = 180) -> [ConexaoVista] {
        var porIp = Dictionary(uniqueKeysWithValues: vistas.map { ($0.ip, $0) })
        for c in ativas { porIp[c.ip] = ConexaoVista(ip: c.ip, vistaEm: agora) }
        return porIp.values.filter { agora.timeIntervalSince($0.vistaEm) <= graca }.sorted { $0.ip < $1.ip }
    }

    public func iniciar() {
        guard laco == nil else { return }
        laco = Task { [weak self] in
            _ = try? await self?.cli.run(["init"], stdin: nil, timeout: 20)
            _ = try? await self?.cli.run(["migrar-keychain"], stdin: nil, timeout: 20)
            while let self, !Task.isCancelled {
                await self.atualizar()
                let n = Self.intervalo(janelaAberta: self.janelaAberta, estado: self.estado)
                try? await Task.sleep(for: .seconds(n))
            }
        }
    }

    public func atualizar() async {
        guard let novo = try? await cli.json(Status.self, ["status", "--json"], timeout: 15) else { return }
        let ipMudou = novo.ipMac != status?.ipMac
        status = novo
        if paises.isEmpty { await carregarPaises() }
        if ipMudou || celular == nil { celular = try? await cli.json(Celular.self, ["celular", "--json"]) }
        avaliarRede(novo.ipMac)
        avaliarEvento(novo)
        if abaCelularAberta, let ativas = try? await cli.json([Conexao].self, ["conexoes", "--json"]) {
            conexoes = Self.mesclar(conexoes, ativas: ativas, agora: Date())
        }
    }

    public func carregarPaises() async {
        if let lista = try? await cli.json([Pais].self, ["paises", "--json"]) { paises = lista }
    }

    private func avaliarRede(_ ip: String?) {
        guard let ip else { return }
        let ultimo = defaults.string(forKey: "ultimoIpMac")
        if ultimo == nil { defaults.set(ip, forKey: "ultimoIpMac") }
        redeMudou = ultimo != nil && ultimo != ip
        ipMacAnterior = redeMudou ? ultimo : nil
    }

    public func confirmarRede() {
        if let ip = status?.ipMac { defaults.set(ip, forKey: "ultimoIpMac") }
        redeMudou = false
        ipMacAnterior = nil
    }

    private func avaliarEvento(_ s: Status) {
        let chave = "ultimoEvento"
        guard let cod = s.motivoCodigo, let motivo = s.motivo else {
            defaults.removeObject(forKey: chave)
            return
        }
        guard defaults.string(forKey: chave) != cod + motivo else { return }
        defaults.set(cod + motivo, forKey: chave)
        notificar(cod, motivo)
    }

    // MARK: Seleção (só da interface: nada muda até Conectar)

    public func selecionar(_ codigo: String) {
        guard let p = paises.first(where: { $0.codigo == codigo }), !ocupado else { return }
        if p.ovpn == 0 {
            mensagem = "Sem arquivo .ovpn de \(p.nomePT). Importe na aba Conta."
            selecionado = nil
        } else {
            selecionado = codigo == status?.codigo ? nil : codigo
        }
    }

    public func limparSelecao() { selecionado = nil }

    // MARK: Ações

    private func acao(_ args: [String]) async {
        guard !ocupado else { return }
        acaoEmAndamento = true
        cancelado = false
        mensagem = nil
        etapa = nil
        inicioConexao = Date()
        log.append("$ vpn \(args.joined(separator: " "))")
        do {
            try await cli.stream(args, timeout: 300) { [weak self] linha in
                Task { @MainActor in self?.receber(linha) }
            }
        } catch CLIError.timeout(let s) {
            mensagem = "O comando demorou demais (\(s) s)."
        } catch CLIError.falhou(let m) {
            if !cancelado { mensagem = m }
        } catch {
            mensagem = "O comando falhou."
        }
        if cancelado { _ = try? await cli.run(["down"], stdin: nil, timeout: 60) }
        acaoEmAndamento = false
        etapa = nil
        inicioConexao = nil
        await atualizar()
    }

    private func receber(_ linha: String) {
        log.append(linha)
        if log.count > 500 { log.removeFirst(log.count - 500) }
        if linha.hasPrefix("etapa: ") { etapa = Etapa(rawValue: String(linha.dropFirst(7))) }
    }

    public func ligar() async { await acao(["up"]) }
    public func desligar() async { await acao(["down"]) }

    public func conectarSelecionado() async {
        guard let p = paisSelecionado else { return }
        selecionado = nil
        await acao(["up", p.apelido])
    }

    public func cancelar() {
        cancelado = true
        cli.cancelar()
    }

    /// Com a VPN desligada só grava; ligada, reconecta no caminho novo.
    public func aplicarCaminho(_ c: Caminho, saida: String?) async {
        let s = saida ?? "auto"
        if estado == .desligada || estado == .erro {
            guard !ocupado, c != .proton else { return }
            _ = try? await cli.run(["caminho", c.rawValue, "--saida", s], stdin: nil, timeout: 20)
            await atualizar()
        } else {
            await acao(c == .sotor ? ["up", "--so-tor", "--saida", s] : ["up", "--tor"])
        }
    }

    /// Vale para uma conexão: o CLI não guarda Só Proton.
    public func ativarSoProton(confirmacao: String) async {
        guard confirmacao == "ENTENDO" else { return }
        await acao(["up", "--so-proton", "--confirmo-quebrar-anonimato"])
    }

    public func salvarCredenciais(usuario: String, senha: String) async throws {
        _ = try await cli.run(["credenciais-openvpn"], stdin: "\(usuario)\n\(senha)\n", timeout: 20)
        await atualizar()
    }

    public func importar(pastas: [URL]) async throws -> Importacao {
        let i = try await cli.json(Importacao.self, ["importar-ovpn"] + pastas.map(\.path))
        await carregarPaises()
        return i
    }

    public func carregarLogs() async {
        if let r = try? await cli.run(["logs"], stdin: nil, timeout: 20) {
            log = r.stdout.split(separator: "\n").suffix(500).map(String.init)
        }
    }
}
