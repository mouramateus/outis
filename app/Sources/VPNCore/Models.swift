import Foundation

public enum Estado: String, Decodable, Sendable { case desligada, conectando, ligada, erro }
public enum Caminho: String, Codable, Sendable { case tor, sotor, proton }

/// Contrato do `./vpn status --json`.
public struct Status: Decodable, Equatable, Sendable {
    public var estado: Estado
    public var modo: Caminho
    public var pais: String
    public var codigo: String?
    public var ipSaida: String?
    public var cidade: String?
    public var paisIp: String?
    public var desde: Date?
    public var ipMac: String?
    public var rede: String?
    public var porta: Int
    public var aviso: String?
    public var codigoErro: String?
    public var mensagemErro: String?
    public var operacao: String?
    public var motivoCodigo: String?
    public var motivo: String?
    public var credenciais: Bool
    public var saidaTor: String?
    public var torConferido: Bool
    public var macEstado: String?
    public var macIp: String?
    public var macSaida: String?
    public var conflitoOrbstack: Bool?
}

/// Apps da Rota 1: só entram os que seguem o proxy do sistema.
public enum AppsDoMac {
    static let navegadores = ["Safari", "Google Chrome", "Microsoft Edge", "Brave Browser", "Firefox", "Arc", "Opera", "Vivaldi"]
    static let dependem = ["Slack", "Discord", "Notion", "Spotify", "Visual Studio Code", "Cursor"]
    public static let fora = ["Terminal e linha de comando", "OrbStack e Docker", "Tor Browser (usa o próprio Tor)", "Mail, Mensagens e iCloud", "FaceTime, Zoom e chamadas", "Jogos"]

    public static func grupos(instalado: (String) -> Bool) -> (incluidos: [String], depende: [String], fora: [String]) {
        (navegadores.filter(instalado), dependem.filter(instalado), fora)
    }
}

public struct Pais: Decodable, Identifiable, Equatable, Sendable {
    public var apelido: String
    public var nome: String
    public var codigo: String
    public var ovpn: Int
    public var atual: Bool

    public var id: String { codigo }

    public var nomePT: String {
        let nomes = ["us": "Estados Unidos", "ca": "Canadá", "mx": "México", "nl": "Holanda", "ch": "Suíça",
                     "no": "Noruega", "pl": "Polônia", "ro": "Romênia", "jp": "Japão", "sg": "Singapura"]
        return nomes[codigo] ?? nome
    }

    public var nomeCurto: String { codigo == "us" ? "EUA" : nomePT }

    public var bandeira: String {
        codigo.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }
            .map { String($0) }.joined()
    }
}

public struct Celular: Decodable, Equatable, Sendable {
    public var chave: String?
    public var ipMac: String?
    public var porta: Int
}

public struct Conexao: Decodable, Equatable, Identifiable, Sendable {
    public var ip: String
    public var id: String { ip }
}

public struct Importacao: Decodable, Equatable, Sendable {
    public var importados: Int
    public var recusados: Int
    public var porPais: [String: Int]
}

public func decodificar<T: Decodable>(_ tipo: T.Type, de json: String) throws -> T {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    d.dateDecodingStrategy = .secondsSince1970
    return try d.decode(T.self, from: Data(json.utf8))
}
