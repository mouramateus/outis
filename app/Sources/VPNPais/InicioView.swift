import SwiftUI
import VPNCore

private let proporcao = CGSize(width: 840, height: 640)

/// Maior retângulo 840×640 centrado: o mapa nunca distorce.
private func quadro(_ t: CGSize) -> CGRect {
    let e = min(t.width / proporcao.width, t.height / proporcao.height)
    let s = CGSize(width: proporcao.width * e, height: proporcao.height * e)
    return CGRect(origin: CGPoint(x: (t.width - s.width) / 2, y: (t.height - s.height) / 2), size: s)
}

private func ponto(_ lat: Double, _ lon: Double, _ q: CGRect) -> CGPoint {
    let p = WorldMap.projetar(lat: lat, lon: lon, em: q.size)
    return CGPoint(x: p.x + q.minX, y: p.y + q.minY)
}

struct InicioView: View {
    let store: StatusStore
    @Binding var aba: Aba
    @State private var saltos: [String] = []
    private let relogio = Timer.publish(every: 600, on: .main, in: .common).autoconnect()

    private var soTor: Bool { store.status?.modo == .sotor }
    private var mostraRota: Bool { store.estado == .ligada || store.estado == .conectando }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(white: 0.075), Cor.fundo], center: .center, startRadius: 40, endRadius: 620)
            GeometryReader { g in
                let q = quadro(g.size)
                PontosDoMapa(quadro: q)
                if mostraRota { Rota(store: store, saltos: saltos, quadro: q, pausada: store.estado != .ligada) }
                marcadores(q)
            }
            VStack(alignment: .trailing) {
                chip
                Spacer()
                StatusCard(store: store, aba: $aba)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(16)
            HStack {
                VStack { Spacer(); legenda }
                Spacer()
            }
            .padding(18)
        }
        .onAppear(perform: sortear)
        .onChange(of: store.status?.desde) { _, _ in sortear() }
        .onChange(of: store.paises.count) { _, _ in sortear() }
        .onReceive(relogio) { _ in sortear() }
    }

    private func sortear() {
        let d = store.paises.filter { $0.ovpn > 0 }.map(\.codigo)
        saltos = WorldMap.sortearSaltos(disponiveis: d, atual: soTor ? nil : store.status?.codigo)
    }

    private func marcadores(_ q: CGRect) -> some View {
        let casa = ponto(WorldMap.casa.lat, WorldMap.casa.lon, q)
        return ZStack {
            Circle().fill(Cor.apagado).frame(width: 7, height: 7).position(casa)
            Text("seu Mac").font(.system(size: 11.5)).foregroundStyle(Color(white: 0.8))
                .position(x: casa.x + 34, y: casa.y)
            ForEach(store.paises) { p in
                if let c = WorldMap.cidades[p.codigo] {
                    Marcador(pais: p,
                             atual: !soTor && p.codigo == store.status?.codigo && store.estado != .desligada,
                             selecionado: p.codigo == store.selecionado,
                             salto: mostraRota && saltos.contains(p.codigo),
                             clicavel: !soTor) { store.selecionar(p.codigo) }
                        .position(ponto(c.lat, c.lon, q))
                }
            }
        }
    }

    private var chip: some View {
        HStack(spacing: 8) {
            Text("Mac").foregroundStyle(Cor.apagado)
            Text(store.status?.ipMac ?? "sem rede").fontWeight(.semibold)
            separador
            Text(store.status?.rede == "cabo" ? "Cabo" : store.status?.rede == "wifi" ? "Wi-Fi" : "Sem rede")
            separador
            Text(store.conexoes.count == 1 ? "1 conexão" : "\(store.conexoes.count) conexões")
            if store.macEstado == "ligada" { separador; Text("Mac pelo Tor") }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .vidro(raio: 16)
    }

    private var separador: some View { Rectangle().fill(Cor.linhaForte).frame(width: 1, height: 12) }

    private var legenda: some View {
        VStack(alignment: .leading, spacing: 6) {
            linhaLegenda("país atual") { Circle().fill(.white).shadow(color: .white, radius: 4) }
            linhaLegenda("selecionado (clique em Conectar)") { Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 1.4, dash: [2, 2])) }
            linhaLegenda("disponível") { Circle().fill(Cor.sutil) }
            linhaLegenda("sem arquivo .ovpn") { Circle().strokeBorder(Cor.sutil, style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
            linhaLegenda("Tor ×3 (simulação)") { Circle().strokeBorder(Color(white: 0.8), lineWidth: 1) }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Cor.apagado)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .vidro(raio: 14)
    }

    private func linhaLegenda<V: View>(_ t: String, @ViewBuilder _ s: () -> V) -> some View {
        HStack(spacing: 8) { s().frame(width: 8, height: 8); Text(t) }
    }
}

/// Camada estática: só redesenha se o tamanho mudar.
private struct PontosDoMapa: View, Equatable {
    let quadro: CGRect
    var body: some View {
        Canvas { ctx, _ in
            var cor = ctx
            cor.opacity = 1
            for p in WorldMap.pontos() {
                let c = ponto(p.lat, p.lon, quadro)
                cor.fill(Path(ellipseIn: CGRect(x: c.x - 1.5, y: c.y - 1.5, width: 3, height: 3)), with: .color(Cor.ponto))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Marcador: View {
    let pais: Pais
    let atual: Bool
    let selecionado: Bool
    let salto: Bool
    let clicavel: Bool
    let acao: () -> Void

    private var semArquivo: Bool { pais.ovpn == 0 }
    private var destaque: Bool { atual || selecionado }
    private var deslocamento: CGSize {
        switch pais.codigo {
        case "nl": CGSize(width: -30, height: -10)
        case "ch": CGSize(width: -22, height: 15)
        case "pl": CGSize(width: 30, height: -9)
        case "ro": CGSize(width: 34, height: 11)
        case "no": CGSize(width: 32, height: -8)
        case "ca": CGSize(width: 30, height: -9)
        case "us": CGSize(width: -22, height: -14)
        case "jp": selecionado ? CGSize(width: -74, height: -14) : CGSize(width: 24, height: -12)
        case "sg": CGSize(width: -36, height: -9)
        default: CGSize(width: semArquivo ? 58 : 34, height: -9)
        }
    }

    var body: some View {
        Button(action: acao) {
            ZStack {
                if atual { Circle().fill(.white.opacity(0.08)).frame(width: 24, height: 24) }
                if salto && !atual { Circle().strokeBorder(Color(white: 0.8), lineWidth: 1).frame(width: 14, height: 14) }
                if selecionado { Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 1.4, dash: [3, 2.5])).frame(width: 18, height: 18) }
                if semArquivo {
                    Circle().strokeBorder(Cor.sutil, style: StrokeStyle(lineWidth: 1, dash: [2, 1.6])).frame(width: 7, height: 7)
                } else {
                    Circle().fill(destaque ? .white : Cor.sutil).frame(width: atual ? 9 : 7, height: atual ? 9 : 7)
                        .shadow(color: atual ? .white : .clear, radius: 5)
                }
                Text(rotulo)
                    .font(.system(size: destaque ? 12 : 11, weight: destaque ? .semibold : .regular))
                    .foregroundStyle(destaque ? .white : Cor.apagado)
                    .fixedSize()
                    .offset(deslocamento)
                    .allowsHitTesting(false)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!clicavel)
        .accessibilityLabel(pais.nomePT + (semArquivo ? ", sem arquivo .ovpn" : "") + (atual ? ", país atual" : "") + (selecionado ? ", selecionado" : ""))
    }

    private var rotulo: String {
        pais.nomeCurto + (semArquivo ? " · sem .ovpn" : "") + (selecionado ? " · selecionado" : "")
    }
}

/// Simulação do caminho: seu Mac, 3 países sorteados e o destino. No Só Proton não há Tor no meio.
private struct Rota: View {
    let store: StatusStore
    let saltos: [String]
    let quadro: CGRect
    let pausada: Bool
    @Environment(\.accessibilityReduceMotion) private var semMovimento

    private var caminho: Path {
        var pts = [ponto(WorldMap.casa.lat, WorldMap.casa.lon, quadro)]
        let modo = store.status?.modo ?? .tor
        if modo != .proton {
            pts += saltos.compactMap { WorldMap.cidades[$0] }.map { ponto($0.lat, $0.lon, quadro) }
        }
        if modo != .sotor, let c = WorldMap.cidades[store.status?.codigo ?? ""] { pts.append(ponto(c.lat, c.lon, quadro)) }
        var p = Path()
        guard let inicio = pts.first else { return p }
        p.move(to: inicio)
        for i in pts.indices.dropFirst() {
            let a = pts[i - 1], b = pts[i]
            let dx = b.x - a.x, dy = b.y - a.y, d = (dx * dx + dy * dy).squareRoot()
            p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 - dy * 0.16, y: (a.y + b.y) / 2 + dx * 0.16 - d * 0.04))
        }
        return p
    }

    var body: some View {
        let parado = pausada || semMovimento
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: parado)) { t in
            Canvas { ctx, _ in
                let c = caminho
                ctx.stroke(c, with: .color(.white.opacity(0.16)), lineWidth: 1.2)
                guard !parado else { return }
                let fase = t.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
                ctx.stroke(c, with: .color(.white.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [6, 340], dashPhase: 346 * (1 - fase)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
