import CoreGraphics

/// Mapa de pontos desenhado no app: terra por faixa de latitude, projeção equiretangular.
public enum WorldMap {
    public static let latTopo = 84.0, latBase = -60.0

    public static let terra: [Int: [ClosedRange<Double>]] = [
        80: [-70 ... -20, 10...30, 50...100], 75: [-120 ... -70, -70 ... -20, 60...140],
        70: [-165 ... -140, -140 ... -60, -55 ... -20, 20...180],
        65: [-165 ... -140, -140 ... -60, -50 ... -35, -25 ... -15, 10...30, 30...180],
        60: [-160 ... -140, -135 ... -65, -50 ... -40, 5...30, 30...165],
        55: [-130 ... -60, -8...0, 5...40, 40...160], 50: [-125 ... -55, -5...0, 0...140, 140...145],
        45: [-125 ... -65, -5...45, 45...135, 140...145],
        40: [-125 ... -75, -10...0, 10...45, 45...120, 125...130, 135...142],
        35: [-120 ... -80, -10...15, 35...50, 50...70, 75...120, 130...140],
        30: [-115 ... -80, -115 ... -105, -10...32, 35...50, 50...70, 70...120],
        25: [-110 ... -97, -82 ... -80, -15...35, 37...57, 62...90, 95...120, 120...122],
        20: [-105 ... -87, -85 ... -75, -17...38, 40...58, 70...87, 92...110],
        15: [-92 ... -84, -17...40, 43...50, 74...80, 95...108, 120...125],
        10: [-86 ... -77, -73 ... -60, -15...50, 76...80, 98...106, 122...126],
        5: [-77 ... -52, -10...48, 100...104, 110...118], 0: [-80 ... -50, 9...42, 98...105, 109...118, 120...125],
        -5: [-80 ... -35, 12...40, 105...115, 132...150], -10: [-78 ... -35, 13...40, 130...150],
        -15: [-75 ... -38, 12...40, 44...50, 125...145], -20: [-70 ... -40, 13...35, 44...48, 115...150],
        -25: [-70 ... -47, 15...33, 113...153], -30: [-71 ... -50, 17...31, 115...153],
        -35: [-72 ... -55, 18...25, 117...150], -40: [-73 ... -62, 145...148, 172...178],
        -45: [-75 ... -65, 167...172], -50: [-75 ... -68], -55: [-72 ... -66],
    ]

    public static let cidades: [String: (lat: Double, lon: Double)] = [
        "us": (41.9, -87.6), "ca": (45.5, -73.6), "mx": (19.4, -99.1), "nl": (52.4, 4.9), "ch": (46.9, 7.4),
        "no": (59.9, 10.7), "pl": (52.2, 21), "ro": (44.4, 26.1), "jp": (35.7, 139.7), "sg": (1.35, 103.8),
    ]

    public static let casa = (lat: -15.8, lon: -47.9)

    public static func projetar(lat: Double, lon: Double, em t: CGSize) -> CGPoint {
        CGPoint(x: (lon + 180) / 360 * t.width, y: (latTopo - lat) / (latTopo - latBase) * t.height)
    }

    public static func pontos(passo: Double = 2.5) -> [(lat: Double, lon: Double)] {
        var saida: [(lat: Double, lon: Double)] = []
        var lat = 82.5
        while lat >= -57.5 {
            let faixa = terra[Int((lat / 5).rounded()) * 5] ?? []
            var lon = -178.75
            while lon <= 180 {
                if faixa.contains(where: { $0.contains(lon) }) { saida.append((lat, lon)) }
                lon += passo
            }
            lat -= passo
        }
        return saida
    }

    /// Simulação do caminho do Tor: até 3 países sorteados entre os que têm .ovpn, sem repetir e sem o atual.
    public static func sortearSaltos(disponiveis: [String], atual: String?) -> [String] {
        Array(disponiveis.filter { $0 != atual }.shuffled().prefix(3))
    }
}
