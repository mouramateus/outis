import AppKit
import SwiftUI
import VPNCore

/// Capuz em pixel art 16×16, desenhado ponto a ponto para ficar nítido na barra de menus.
/// Imagem template: acompanha barra clara ou escura.
private enum Capuz {
    static let inteiro = [
        ".....######.....", "....########....", "...###....###...", "..###......###..",
        "..##.######.##..", "..##........##..", "..##.#####..##..", "..##........##..",
        "..###.####.###..", "...###....###...", "....########....", "..############..",
        ".##############.", "################", "################", "................",
    ]
    static let desfazendo = [
        ".....######.....", "....#######.....", "...###....#.#...", "..###......#..#.",
        "..##.####...#...", "..##......#...#.", "..##.###....#...", "..##.........#.#",
        "..###.##...#....", "...###....#...#.", "....#####.#.#...", "..#########...#.",
        ".##########.#...", "##########..#.#.", "#########.#...#.", "................",
    ]

    static func imagem(_ linhas: [String], opacidade: CGFloat = 1) -> NSImage {
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.black.withAlphaComponent(opacidade).setFill()
            for (j, l) in linhas.enumerated() {
                for (i, c) in l.enumerated() where c == "#" { NSRect(x: i, y: j, width: 1, height: 1).fill() }
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}

struct MenuBarIcon: View {
    let store: StatusStore

    var body: some View {
        HStack(spacing: 4) {
            simbolo
            if let sigla { Text(sigla) }
        }
        .accessibilityLabel(rotulo)
    }

    @ViewBuilder private var simbolo: some View {
        if store.ocupado || store.estado == .conectando {
            Image(nsImage: Capuz.imagem(Capuz.desfazendo))
        } else if store.estado == .erro || store.macEstado == "erro" {
            Image(systemName: "exclamationmark.circle")
        } else if store.estado == .ligada || store.macEstado == "ligada" {
            Image(nsImage: Capuz.imagem(Capuz.inteiro))
        } else {
            Image(nsImage: Capuz.imagem(Capuz.inteiro, opacidade: 0.45))
        }
    }

    /// País do celular e, se o Mac estiver na rota dele, MAC.
    private var sigla: String? {
        var partes: [String] = []
        if store.estado == .ligada {
            partes.append(store.status?.modo == .sotor ? "TOR" : store.status?.codigo?.uppercased() ?? "")
        }
        if store.macEstado == "ligada" { partes.append("MAC") }
        return partes.isEmpty ? nil : partes.joined(separator: "+")
    }

    private var rotulo: String {
        if let a = store.atividade { return a.texto }
        if store.macEstado == "ligada", store.estado != .ligada { return "Este Mac ligado, celular desligado" }
        if store.macEstado == "ligada" { return "Celular e este Mac ligados" }
        switch store.estado {
        case .ligada: return "VPN ligada"
        case .conectando: return "VPN conectando"
        case .erro: return "VPN com erro"
        case .desligada: return "VPN desligada"
        }
    }
}
