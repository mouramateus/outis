import CoreGraphics
import Testing
@testable import VPNCore

@Test func projetaCantos() {
    let t = CGSize(width: 840, height: 640)
    let a = WorldMap.projetar(lat: 84, lon: -180, em: t)
    let b = WorldMap.projetar(lat: -60, lon: 180, em: t)
    #expect(a == .zero)
    #expect(abs(b.x - 840) < 0.001 && abs(b.y - 640) < 0.001)
}

@Test func cidadesCaemEmTerra() {
    for (k, c) in WorldMap.cidades {
        let faixa = WorldMap.terra[Int((c.lat / 5).rounded()) * 5] ?? []
        #expect(faixa.contains { $0.lowerBound - 5 <= c.lon && c.lon <= $0.upperBound + 5 }, "\(k)")
    }
}

@Test func pontosDoMapa() {
    #expect(WorldMap.pontos().count > 1500)
}

@Test func sorteiaTresSemRepetirESemOAtual() {
    let disponiveis = ["us", "ca", "nl", "ch", "no", "pl", "ro", "jp", "sg"]
    for _ in 0..<200 {
        let s = WorldMap.sortearSaltos(disponiveis: disponiveis, atual: "us")
        #expect(s.count == 3)
        #expect(Set(s).count == 3)
        #expect(!s.contains("us"))
        #expect(s.allSatisfy { disponiveis.contains($0) })
    }
}

@Test func sorteioComPoucosPaises() {
    #expect(WorldMap.sortearSaltos(disponiveis: ["us", "jp"], atual: "us") == ["jp"])
    #expect(WorldMap.sortearSaltos(disponiveis: [], atual: nil).isEmpty)
}

@Test func sorteioVaria() {
    let d = ["us", "ca", "nl", "ch", "no", "pl", "ro", "jp", "sg"]
    let rotas = Set((0..<30).map { _ in WorldMap.sortearSaltos(disponiveis: d, atual: "us").joined() })
    #expect(rotas.count > 1)
}
