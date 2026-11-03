import Foundation

public struct CLIResult: Sendable {
    public let code: Int32
    public let stdout: String
    public let stderr: String
}

public enum CLIError: Error, Equatable {
    case timeout(Int)
    case falhou(String)
}

public protocol CLIProtocol: Sendable {
    func run(_ args: [String], stdin: String?, timeout: Int) async throws -> CLIResult
    func stream(_ args: [String], timeout: Int, linha: @Sendable @escaping (String) -> Void) async throws
    func cancelar()
}

extension CLIProtocol {
    public func json<T: Decodable>(_ tipo: T.Type, _ args: [String], timeout: Int = 20) async throws -> T {
        try decodificar(T.self, de: try await run(args, stdin: nil, timeout: timeout).stdout)
    }
}

/// Chama o `./vpn`. Não bloqueia: uma ação longa não atrasa as leituras de estado.
public final class VPNCLI: CLIProtocol, @unchecked Sendable {
    private let executavel: URL
    private let trava = NSLock()
    private var atual: Process?

    public init(executavel: URL) { self.executavel = executavel }

    public func run(_ args: [String], stdin: String?, timeout: Int) async throws -> CLIResult {
        try await executar(args, stdin: stdin, timeout: timeout, cancelavel: false, linha: nil)
    }

    public func stream(_ args: [String], timeout: Int, linha: @Sendable @escaping (String) -> Void) async throws {
        _ = try await executar(args, stdin: nil, timeout: timeout, cancelavel: true, linha: linha)
    }

    /// Manda TERM à ação em andamento; o CLI libera a trava sozinho.
    public func cancelar() {
        trava.withLock { atual }?.terminate()
    }

    private func executar(_ args: [String], stdin: String?, timeout: Int, cancelavel: Bool,
                          linha: (@Sendable (String) -> Void)?) async throws -> CLIResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [executavel.path] + args
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        env["PATH"] = "\(home)/.orbstack/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["VPN_NOTIFY"] = "app"
        p.environment = env

        let saida = Pipe(), erro = Pipe(), entrada = Pipe()
        p.standardOutput = saida
        p.standardError = erro
        p.standardInput = entrada

        let coleta = Coleta(linha: linha)
        saida.fileHandleForReading.readabilityHandler = { coleta.soma(saida: $0.availableData) }
        erro.fileHandleForReading.readabilityHandler = { coleta.soma(erro: $0.availableData) }

        if cancelavel { trava.withLock { atual = p } }

        let resultado: CLIResult = try await withCheckedThrowingContinuation { cont in
            p.terminationHandler = { proc in
                // Espera o resto dos pipes sem bloquear: um neto pode manter o pipe aberto.
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
                    saida.fileHandleForReading.readabilityHandler = nil
                    erro.fileHandleForReading.readabilityHandler = nil
                    if coleta.estourou { cont.resume(throwing: CLIError.timeout(timeout)); return }
                    let r = coleta.resultado(codigo: proc.terminationStatus)
                    if r.code != 0 && r.code != 143 {
                        cont.resume(throwing: CLIError.falhou(mensagemDeErro(r.stderr)))
                    } else {
                        cont.resume(returning: r)
                    }
                }
            }
            do {
                try p.run()
            } catch {
                cont.resume(throwing: CLIError.falhou("Não consegui executar o CLI."))
                return
            }
            if let stdin { entrada.fileHandleForWriting.write(Data(stdin.utf8)) }
            try? entrada.fileHandleForWriting.close()
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout)) {
                if p.isRunning { coleta.marcaEstouro(); p.terminate() }
            }
        }
        if cancelavel { trava.withLock { atual = nil } }
        return resultado
    }
}

func mensagemDeErro(_ stderr: String) -> String {
    let linhas = stderr.split(separator: "\n").map(String.init)
    if let m = linhas.last(where: { $0.hasPrefix("Erro: ") }) { return String(m.dropFirst(6)) }
    return linhas.last ?? "O comando falhou."
}

private final class Coleta: @unchecked Sendable {
    private let trava = NSLock()
    private var out = Data(), err = Data(), resto = Data()
    private var estouro = false
    private let linha: (@Sendable (String) -> Void)?

    init(linha: (@Sendable (String) -> Void)?) { self.linha = linha }

    func soma(saida d: Data) {
        guard !d.isEmpty else { return }
        trava.lock()
        out.append(d); resto.append(d)
        var prontas: [String] = []
        while let i = resto.firstIndex(of: 10) {
            prontas.append(String(decoding: resto[resto.startIndex..<i], as: UTF8.self))
            resto = Data(resto[(i + 1)...])
        }
        trava.unlock()
        prontas.forEach { linha?($0) }
    }

    func soma(erro d: Data) { trava.lock(); err.append(d); trava.unlock() }
    func marcaEstouro() { trava.lock(); estouro = true; trava.unlock() }
    var estourou: Bool { trava.lock(); defer { trava.unlock() }; return estouro }

    func resultado(codigo: Int32) -> CLIResult {
        trava.lock(); defer { trava.unlock() }
        return CLIResult(code: codigo, stdout: String(decoding: out, as: UTF8.self), stderr: String(decoding: err, as: UTF8.self))
    }
}
