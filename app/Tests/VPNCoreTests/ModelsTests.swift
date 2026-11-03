import Foundation
import Testing
@testable import VPNCore

@Test func decodificaStatusLigada() throws {
    let json = #"{"estado":"ligada","modo":"tor","pais":"United States","codigo":"us","ip_saida":"89.1.1.1","cidade":"Chicago","pais_ip":"United States","desde":1793744841,"ip_mac":"192.168.1.52","rede":"wifi","porta":8388,"aviso":null,"codigo_erro":null,"mensagem_erro":null,"operacao":null,"motivo_codigo":null,"motivo":null,"credenciais":true,"saida_tor":null,"tor_conferido":true}"#
    let s = try decodificar(Status.self, de: json)
    #expect(s.estado == .ligada)
    #expect(s.modo == .tor)
    #expect(s.ipSaida == "89.1.1.1")
    #expect(s.ipMac == "192.168.1.52")
    #expect(s.torConferido)
    #expect(s.desde == Date(timeIntervalSince1970: 1793744841))
}

@Test func decodificaStatusComNulos() throws {
    let json = #"{"estado":"desligada","modo":"sotor","pais":"Japan","codigo":null,"ip_saida":null,"cidade":null,"pais_ip":null,"desde":null,"ip_mac":null,"rede":null,"porta":8388,"aviso":"orbstack","codigo_erro":null,"mensagem_erro":null,"operacao":"up","motivo_codigo":"rede","motivo":"m","credenciais":false,"saida_tor":"auto","tor_conferido":false}"#
    let s = try decodificar(Status.self, de: json)
    #expect(s.modo == .sotor)
    #expect(s.ipSaida == nil)
    #expect(s.aviso == "orbstack")
    #expect(s.operacao == "up")
}

@Test func paisTemNomeEBandeira() throws {
    let lista = try decodificar([Pais].self, de: #"[{"apelido":"japao","nome":"Japan","codigo":"jp","ovpn":3,"atual":false}]"#)
    #expect(lista[0].nomePT == "Japão")
    #expect(lista[0].bandeira == "🇯🇵")
    #expect(lista[0].id == "jp")
}

@Test func decodificaImportacao() throws {
    let i = try decodificar(Importacao.self, de: #"{"importados":2,"recusados":1,"por_pais":{"us":3,"mx":0}}"#)
    #expect(i.importados == 2)
    #expect(i.porPais["us"] == 3)
}
