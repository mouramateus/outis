import SwiftUI

enum Cor {
    static let fundo = Color(red: 0.02, green: 0.02, blue: 0.024)
    static let texto = Color(white: 0.95)
    static let apagado = Color(red: 0.64, green: 0.64, blue: 0.66) // 8:1 sobre o preto
    static let sutil = Color(red: 0.55, green: 0.55, blue: 0.58)   // 6:1, mínimo para texto
    static let ponto = Color(red: 0.22, green: 0.22, blue: 0.245)  // decorativo
    static let linha = Color.white.opacity(0.12)
    static let linhaForte = Color.white.opacity(0.24)
}

/// Vidro nativo no macOS 26+; antes disso, material translúcido. Com "Reduzir transparência", fundo sólido.
struct Vidro: ViewModifier {
    var raio: CGFloat = 18
    @Environment(\.accessibilityReduceTransparency) private var semTransparencia

    func body(content: Content) -> some View {
        let forma = RoundedRectangle(cornerRadius: raio, style: .continuous)
        Group {
            if semTransparencia {
                content.background(Color(white: 0.11), in: forma)
            } else if #available(macOS 26, *) {
                content.glassEffect(.regular, in: forma)
            } else {
                content.background(.ultraThinMaterial, in: forma)
            }
        }
        .overlay(forma.strokeBorder(Cor.linha, lineWidth: 1))
    }
}

extension View {
    func vidro(raio: CGFloat = 18) -> some View { modifier(Vidro(raio: raio)) }
}

struct BotaoPrincipal: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(white: 0.04))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(Color(white: 0.95).opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
    }
}

struct BotaoVidro: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Cor.texto)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Cor.linhaForte, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

/// Círculo com ícone: desligar (branco) ou abrir o app (vidro).
struct BotaoIcone: View {
    let simbolo: String
    let rotulo: String
    var claro = true
    var tamanho: CGFloat = 44
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Image(systemName: simbolo)
                .font(.system(size: tamanho * 0.38, weight: .semibold))
                .foregroundStyle(claro ? Color(white: 0.07) : Cor.texto)
                .frame(width: tamanho, height: tamanho)
                .background(Circle().fill(claro ? AnyShapeStyle(Color(white: 0.92)) : AnyShapeStyle(Color.white.opacity(0.1))))
                .overlay(Circle().strokeBorder(claro ? Color.clear : Cor.linhaForte, lineWidth: 1))
                .shadow(color: .white.opacity(claro ? 0.3 : 0), radius: 10)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(rotulo)
        .accessibilityLabel(rotulo)
    }
}

struct Selo: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 11, weight: .medium)).foregroundStyle(Cor.texto)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay(Capsule().strokeBorder(Cor.linhaForte, lineWidth: 1))
    }
}

struct PontoEstado: View {
    let estado: EstadoVisual
    @Environment(\.accessibilityReduceMotion) private var semMovimento
    @State private var fraco = false

    var body: some View {
        Group {
            switch estado {
            case .ligado:
                Circle().fill(.white).shadow(color: .white.opacity(0.8), radius: 7)
            case .conectando:
                Circle().fill(Color(white: 0.8)).opacity(fraco ? 0.35 : 1)
            case .parado:
                Circle().strokeBorder(Cor.sutil, lineWidth: 1.5)
            }
        }
        .frame(width: 9, height: 9)
        .onAppear {
            guard estado == .conectando, !semMovimento else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) { fraco = true }
        }
    }
}

enum EstadoVisual { case ligado, conectando, parado }

struct TituloEstado: View {
    let texto: String
    let estado: EstadoVisual
    var body: some View {
        HStack(spacing: 10) {
            PontoEstado(estado: estado)
            Text(texto.uppercased()).font(.system(size: 12.5, weight: .semibold)).kerning(1)
                .foregroundStyle(Cor.texto)
        }
    }
}
