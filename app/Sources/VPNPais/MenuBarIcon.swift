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
            if store.estado == .ligada, store.status?.modo != .sotor, let c = store.status?.codigo {
                Text(c.uppercased())
            }
        }
        .accessibilityLabel(rotulo)
    }

    @ViewBuilder private var simbolo: some View {
        if store.ocupado || store.estado == .conectando {
            Image(nsImage: Capuz.imagem(Capuz.desfazendo))
        } else if store.estado == .erro {
            Image(systemName: "exclamationmark.circle")
        } else if store.estado == .ligada {
            Image(nsImage: Capuz.imagem(Capuz.inteiro))
        } else {
            Image(nsImage: Capuz.imagem(Capuz.inteiro, opacidade: 0.45))
        }
    }

    private var rotulo: String {
        switch store.estado {
        case .ligada: "VPN ligada"
        case .conectando: "VPN conectando"
        case .erro: "VPN com erro"
        case .desligada: "VPN desligada"
        }
    }
}
