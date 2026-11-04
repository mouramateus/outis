import SwiftUI
import VPNCore

struct AvancadoView: View {
    let store: StatusStore
    @State private var escolha: Caminho?
    @State private var saida = "auto"
    @State private var confirmacao = ""

    private var atual: Caminho { store.status?.modo ?? .tor }
    private var marcado: Caminho { escolha ?? atual }
    private var ligada: Bool { store.estado == .ligada }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Caminho do celular").font(.system(size: 16, weight: .semibold))
                opcao(.tor, "Tor + VPN", selo: "padrão · recomendado",
                      "iPhone → Mac → Tor → VPN → internet. Você escolhe o país, e a VPN não vê o seu IP. É lento (~95 KB/s).")
                opcao(.sotor, "Só Tor (sem VPN)", selo: "experimental",
                      "iPhone → Mac → Tor → internet. Não usa a conta da VPN e continua anônimo, mas muitos sites bloqueiam IPs do Tor. Sem UDP: teste no iPhone antes de confiar.") {
                    HStack {
                        Text("País de saída:").font(.system(size: 12.5)).foregroundStyle(Cor.apagado)
                        Picker("País de saída", selection: $saida) {
                            Text("Tor escolhe (padrão)").tag("auto")
                            ForEach(store.paises) { p in Text("\(p.bandeira) \(p.nomeCurto)").tag(p.codigo) }
                        }
                        .labelsHidden().frame(width: 220)
                    }
                    Text("Fixar um país restringe os nós de saída: fica um pouco menos anônimo e pode ficar mais lento.")
                        .font(.system(size: 11.5)).foregroundStyle(Cor.apagado)
                }
                opcao(.proton, "Só VPN (sem Tor)", selo: "vale para uma conexão",
                      "iPhone → Mac → VPN → internet. É bem mais rápido.") {
                    VStack(alignment: .leading, spacing: 8) {
                        (Text("⚠︎ A VPN passa a ver o IP da sua casa ligado à sua conta anônima. Isso não tem volta: mesmo voltando para o Tor, a conta continua ligada a você. Para usar, digite ") + Text("ENTENDO").fontWeight(.bold) + Text(":"))
                            .font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            TextField("", text: $confirmacao).textFieldStyle(.roundedBorder).frame(width: 140)
                                .accessibilityLabel("Digite ENTENDO")
                            Button("Ativar mesmo assim") {
                                Task { await store.ativarSoProton(confirmacao: confirmacao); confirmacao = ""; escolha = nil }
                            }
                            .buttonStyle(BotaoVidro())
                            .disabled(confirmacao != "ENTENDO" || store.ocupado)
                        }
                    }
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white, lineWidth: 1.5))
                }
                if marcado != .proton, marcado != atual || saidaMudou {
                    Button(ligada ? "Aplicar e reconectar" : "Salvar para a próxima conexão") {
                        Task {
                            await store.aplicarCaminho(marcado, saida: marcado == .sotor ? saida : nil)
                            escolha = nil
                        }
                    }
                    .buttonStyle(BotaoPrincipal()).frame(maxWidth: 300).disabled(store.ocupado)
                    if ligada { Text("A troca leva até ~2 min, e o iPhone fica sem VPN nesse tempo.").font(.system(size: 12)).foregroundStyle(Cor.apagado) }
                }
                Text("Outras opções").font(.system(size: 16, weight: .semibold)).padding(.top, 14)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow { Text("Porta do celular").foregroundStyle(Cor.apagado); Text(String(store.status?.porta ?? 8388)) }
                    GridRow { Text("Ao trocar de rede").foregroundStyle(Cor.apagado); Text("desliga tudo (fixo, por segurança)") }
                }
                .font(.system(size: 13))
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.top, 52).padding(.horizontal, 32).padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { saida = store.status?.saidaTor ?? "auto" }
    }

    private var saidaMudou: Bool { marcado == .sotor && saida != (store.status?.saidaTor ?? "auto") }

    private func opcao<V: View>(_ c: Caminho, _ titulo: String, selo: String, _ texto: String, @ViewBuilder extra: () -> V = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { escolha = c } label: {
                HStack(spacing: 10) {
                    Image(systemName: marcado == c ? "largecircle.fill.circle" : "circle")
                    Text(titulo).font(.system(size: 14.5, weight: .semibold))
                    Selo(texto: selo)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(texto).font(.system(size: 12.5)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
            if marcado == c { extra() }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(marcado == c ? Color.white.opacity(0.07) : Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(marcado == c ? Color.white.opacity(0.55) : Cor.linha))
    }
}
