import Foundation
import Testing
@testable import VPNCore

private func script(_ corpo: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cli-\(UUID().uuidString).sh")
    try corpo.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private final class Linhas: @unchecked Sendable {
    private let trava = NSLock()
    private var itens: [String] = []
    func soma(_ s: String) { trava.lock(); itens.append(s); trava.unlock() }
    var todas: [String] { trava.lock(); defer { trava.unlock() }; return itens }
}

@Test func runDevolveSaida() async throws {
    let cli = VPNCLI(executavel: try script("echo oi"))
    let r = try await cli.run(["x"], stdin: nil, timeout: 5)
    #expect(r.stdout == "oi\n")
}

@Test func argumentosChegam() async throws {
    let cli = VPNCLI(executavel: try script(#"echo "$1-$2""#))
    #expect(try await cli.run(["a", "b c"], stdin: nil, timeout: 5).stdout == "a-b c\n")
}

@Test func falhaTrazMensagem() async throws {
    let cli = VPNCLI(executavel: try script("echo 'Erro: Outra operação em andamento.' >&2; exit 1"))
    await #expect(throws: CLIError.falhou("Outra operação em andamento.")) {
        _ = try await cli.run([], stdin: nil, timeout: 5)
    }
}

@Test func timeoutViraErro() async throws {
    let cli = VPNCLI(executavel: try script("sleep 5"))
    let inicio = Date()
    await #expect(throws: CLIError.timeout(1)) {
        _ = try await cli.run([], stdin: nil, timeout: 1)
    }
    #expect(Date().timeIntervalSince(inicio) < 3)
}

@Test func stdinChega() async throws {
    let cli = VPNCLI(executavel: try script("cat"))
    #expect(try await cli.run([], stdin: "abc", timeout: 5).stdout == "abc")
}

@Test func streamEntregaLinhasEmOrdem() async throws {
    let cli = VPNCLI(executavel: try script("echo um; sleep 0.1; echo dois; sleep 0.1; echo tres"))
    let l = Linhas()
    try await cli.stream([], timeout: 5) { l.soma($0) }
    #expect(l.todas == ["um", "dois", "tres"])
}

@Test func statusRespondeDuranteStream() async throws {
    let cli = VPNCLI(executavel: try script(#"[ "$1" = longo ] && sleep 2; echo ok"#))
    async let longo: Void = cli.stream(["longo"], timeout: 5) { _ in }
    try await Task.sleep(for: .milliseconds(200))
    let inicio = Date()
    _ = try await cli.run(["curto"], stdin: nil, timeout: 5)
    #expect(Date().timeIntervalSince(inicio) < 1)
    try await longo
}

@Test func cancelarEncerraOStream() async throws {
    let cli = VPNCLI(executavel: try script("sleep 10"))
    let inicio = Date()
    async let longo: Void = cli.stream([], timeout: 20) { _ in }
    try await Task.sleep(for: .milliseconds(300))
    cli.cancelar()
    _ = await (try? longo)
    #expect(Date().timeIntervalSince(inicio) < 3)
}
