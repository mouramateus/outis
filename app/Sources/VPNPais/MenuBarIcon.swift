import SwiftUI
import VPNCore

/// SF Symbols em modo template: acompanham barra clara ou escura.
struct MenuBarIcon: View {
    let store: StatusStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: simbolo)
            if store.estado == .ligada, store.status?.modo != .sotor, let c = store.status?.codigo {
                Text(c.uppercased())
            }
        }
        .accessibilityLabel(rotulo)
    }

    private var simbolo: String {
        if store.ocupado || store.estado == .conectando { return "arrow.triangle.2.circlepath" }
        switch store.estado {
        case .ligada: return "globe.americas.fill"
        case .erro: return "exclamationmark.circle"
        default: return "globe"
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
