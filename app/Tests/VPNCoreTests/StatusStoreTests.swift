import Foundation
import Testing
@testable import VPNCore

private final class FakeCLI: CLIProtocol, @unchecked Sendable {
    private let trava = NSLock()
    private var _chamadas: [[String]] = []
    private var _status: String
    var linhas: [String] = []
    var demora: Duration = .zero
    var falha: CLIError?
    var cancelou = false

    init(status: String = FakeCLI.json()) { _status = status }

    static func json(estado: String = "desligada", modo: String = "tor", ipMac: String = "192.168.1.52", operacao: String = "null", motivo: String = "null", aviso: String = "null") -> String {
        #"{"estado":"\#(estado)","modo":"\#(modo)","pais":"United States","codigo":"us","ip_saida":null,"cidade":null,"pais_ip":null,"desde":null,"ip_mac":"\#(ipMac)","rede":"wifi","porta":8388,"aviso":\#(aviso),"codigo_erro":null,"mensagem_erro":null,"operacao":\#(operacao),"motivo_codigo":\#(motivo),"motivo":"m","credenciais":true,"saida_tor":null,"tor_conferido":false}"#
    }
    func defineStatus(_ s: String) { trava.withLock { _status = s } }
    var chamadas: [[String]] { trava.withLock { _chamadas } }

    func run(_ args: [String], stdin: String?, timeout: Int) async throws -> CLIResult {
        trava.withLock { _chamadas.append(args) }
        if args.first == "status" { return CLIResult(code: 0, stdout: trava.withLock { _status }, stderr: "") }
        if args.first == "paises" { return CLIResult(code: 0, stdout: #"[{"apelido":"eua","nome":"United States","codigo":"us","ovpn":3,"atual":true},{"apelido":"mexico","nome":"Mexico","codigo":"mx","ovpn":0,"atual":false},{"apelido":"japao","nome":"Japan","codigo":"jp","ovpn":2,"atual":false}]"#, stderr: "") }
        if args.first == "celular" { return CLIResult(code: 0, stdout: #"{"chave":"ss://x","ip_mac":"192.168.1.52","porta":8388}"#, stderr: "") }
        if args.first == "conexoes" { return CLIResult(code: 0, stdout: "[]", stderr: "") }
        if let falha { throw falha }
        return CLIResult(code: 0, stdout: "ok", stderr: "")
    }

    func stream(_ args: [String], timeout: Int, linha: @Sendable @escaping (String) -> Void) async throws {
        trava.withLock { _chamadas.append(args) }
        linhas.forEach(linha)
        if demora != .zero { try await Task.sleep(for: demora) }
        if let falha { throw falha }
    }

    func cancelar() { trava.withLock { cancelou = true } }
}

@MainActor private func novoStore(_ cli: FakeCLI) -> (StatusStore, [String]) {
    let d = UserDefaults(suiteName: "teste-\(UUID().uuidString)")!
    return (StatusStore(cli: cli, defaults: d), [])
}

@MainActor @Test func segundaAcaoIgnorada() async throws {
    let cli = FakeCLI(); cli.demora = .milliseconds(200)
    let (s, _) = novoStore(cli)
    async let a: Void = s.ligar()
    try await Task.sleep(for: .milliseconds(50))
    await s.ligar()
    await a
    #expect(cli.chamadas.filter { $0.first == "up" }.count == 1)
}

@MainActor @Test func operacaoExternaBloqueiaAcoes() async {
    let cli = FakeCLI(status: FakeCLI.json(operacao: #""up""#))
    let (s, _) = novoStore(cli)
    await s.atualizar()
    #expect(s.ocupado)
    await s.desligar()
    #expect(!cli.chamadas.contains { $0.first == "down" })
}

@MainActor @Test func selecionarNaoConectaEConectarUsaOApelido() async {
    let cli = FakeCLI(status: FakeCLI.json(estado: "ligada"))
    let (s, _) = novoStore(cli)
    await s.atualizar()
    s.selecionar("jp")
    #expect(s.selecionado == "jp")
    #expect(!cli.chamadas.contains { $0.first == "up" })
    await s.conectarSelecionado()
    #expect(cli.chamadas.contains { $0 == ["up", "japao"] })
    #expect(s.selecionado == nil)
}

@MainActor @Test func paisSemOvpnNaoSeleciona() async {
    let (s, _) = novoStore(FakeCLI())
    await s.atualizar()
    s.selecionar("mx")
    #expect(s.selecionado == nil)
    #expect(s.mensagem?.contains("México") == true)
}

@MainActor @Test func paisAtualLimpaSelecao() async {
    let (s, _) = novoStore(FakeCLI())
    await s.atualizar()
    s.selecionar("jp"); s.selecionar("us")
    #expect(s.selecionado == nil)
}

@MainActor @Test func etapasDoStream() async {
    let cli = FakeCLI(); cli.linhas = ["etapa: tor", "etapa: proton"]; cli.demora = .milliseconds(100)
    let (s, _) = novoStore(cli)
    await s.ligar()
    #expect(s.log.contains("etapa: proton"))
}

@MainActor @Test func entendoExatoParaSoProton() async {
    let cli = FakeCLI()
    let (s, _) = novoStore(cli)
    await s.ativarSoProton(confirmacao: "entendo")
    #expect(!cli.chamadas.contains { $0.first == "up" })
    await s.ativarSoProton(confirmacao: "ENTENDO")
    #expect(cli.chamadas.contains { $0 == ["up", "--so-proton", "--confirmo-quebrar-anonimato"] })
}

@MainActor @Test func caminhoComVpnDesligadaSoGrava() async {
    let cli = FakeCLI()
    let (s, _) = novoStore(cli)
    await s.atualizar()
    await s.aplicarCaminho(.sotor, saida: "de")
    #expect(cli.chamadas.contains { $0 == ["caminho", "sotor", "--saida", "de"] })
}

@MainActor @Test func caminhoComVpnLigadaReconecta() async {
    let cli = FakeCLI(status: FakeCLI.json(estado: "ligada"))
    let (s, _) = novoStore(cli)
    await s.atualizar()
    await s.aplicarCaminho(.sotor, saida: nil)
    #expect(cli.chamadas.contains { $0 == ["up", "--so-tor", "--saida", "auto"] })
}

@MainActor @Test func cancelarEncerraEDesliga() async throws {
    let cli = FakeCLI(); cli.demora = .milliseconds(150)
    let (s, _) = novoStore(cli)
    async let a: Void = s.ligar()
    try await Task.sleep(for: .milliseconds(40))
    s.cancelar()
    await a
    #expect(cli.cancelou)
    #expect(cli.chamadas.contains { $0 == ["down"] })
}

@MainActor @Test func erroDeAcaoViraMensagem() async {
    let cli = FakeCLI(); cli.falha = .falhou("Sem arquivo .ovpn de Mexico.")
    let (s, _) = novoStore(cli)
    await s.ligar()
    #expect(s.mensagem == "Sem arquivo .ovpn de Mexico.")
    #expect(!s.ocupado)
}

@MainActor @Test func timeoutViraMensagem() async {
    let cli = FakeCLI(); cli.falha = .timeout(300)
    let (s, _) = novoStore(cli)
    await s.ligar()
    #expect(s.mensagem == "O comando demorou demais (300 s).")
}

@MainActor @Test func redeMudouQuandoIpDoMacMuda() async {
    let cli = FakeCLI()
    let d = UserDefaults(suiteName: "teste-\(UUID().uuidString)")!
    d.set("192.168.15.3", forKey: "ultimoIpMac")
    let s = StatusStore(cli: cli, defaults: d)
    await s.atualizar()
    #expect(s.redeMudou)
    #expect(s.ipMacAnterior == "192.168.15.3")
    s.confirmarRede()
    #expect(!s.redeMudou)
    #expect(d.string(forKey: "ultimoIpMac") == "192.168.1.52")
}

@MainActor @Test func notificaMotivoNovoUmaVez() async {
    final class Caixa: @unchecked Sendable { var n = 0 }
    let c = Caixa()
    let cli = FakeCLI(status: FakeCLI.json(motivo: #""rede""#))
    let d = UserDefaults(suiteName: "teste-\(UUID().uuidString)")!
    let s = StatusStore(cli: cli, defaults: d, notificar: { _, _ in c.n += 1 })
    await s.atualizar(); await s.atualizar()
    #expect(c.n == 1)
}

@Test func cadencia() {
    #expect(StatusStore.intervalo(janelaAberta: true, estado: .ligada) == 5)
    #expect(StatusStore.intervalo(janelaAberta: false, estado: .conectando) == 5)
    #expect(StatusStore.intervalo(janelaAberta: false, estado: .ligada) == 30)
}

@Test func conexaoFicaListadaPorTresMinutos() {
    let t0 = Date(timeIntervalSince1970: 1000)
    var v = StatusStore.mesclar([], ativas: [Conexao(ip: "1.1.1.1")], agora: t0)
    v = StatusStore.mesclar(v, ativas: [], agora: t0.addingTimeInterval(170))
    #expect(v.count == 1)
    #expect(!v[0].ativa(agora: t0.addingTimeInterval(170)))
    v = StatusStore.mesclar(v, ativas: [], agora: t0.addingTimeInterval(181))
    #expect(v.isEmpty)
}
