import AppKit
import SwiftUI
import VPNCore

struct CelularView: View {
    let store: StatusStore
    @State private var copiou = false

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                qr
                Button(copiou ? "Copiada" : "Copiar chave") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.celular?.chave ?? "", forType: .string)
                    copiou = true
                }
                .buttonStyle(BotaoPrincipal())
                .disabled(store.celular?.chave == nil)
                Text("Leia com a câmera do iPhone e abra no Outline. Evite mandar a chave por mensagem.")
                    .font(.system(size: 11.5)).foregroundStyle(Cor.apagado)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18).frame(width: 300).vidro()

            VStack(spacing: 18) {
                conectar
                conexoes
            }
        }
        .padding(.top, 52).padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var qr: some View {
        if let c = store.celular?.chave, let i = imagemQR(c) {
            Image(nsImage: i).interpolation(.none).resizable().frame(width: 264, height: 264)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("QR code da chave do celular")
        } else {
            Text("Sem rede: conecte o Mac para gerar a chave.")
                .font(.system(size: 13)).foregroundStyle(Cor.apagado).frame(width: 264, height: 264)
        }
    }

    private var conectar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Como conectar").fontWeight(.semibold)
            Text("1. Instale o Outline no iPhone · 2. Leia o QR (ou cole a chave) · 3. Conecte.")
                .font(.system(size: 13)).foregroundStyle(Cor.apagado)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("IP do Mac").foregroundStyle(Cor.apagado)
                    Text("\(store.celular?.ipMac ?? "sem rede") · porta \(String(store.celular?.porta ?? 8388))")
                }
                GridRow {
                    Text("Rede").foregroundStyle(Cor.apagado)
                    Text("\(store.status?.rede == "cabo" ? "Cabo" : "Wi-Fi") (a porta só abre nesta rede)")
                }
            }
            .font(.system(size: 13))
            if store.redeMudou {
                HStack {
                    Text("A rede mudou desde a última vez (antes: \(store.ipMacAnterior ?? "?")). Atualize a chave no Outline.")
                        .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Já atualizei") { store.confirmarRede() }.buttonStyle(BotaoVidro())
                }
                .padding(10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
            (Text("iPhone: ").fontWeight(.semibold) + Text("ele não bloqueia a internet quando a VPN cai. Se o Mac dormir ou mudar de rede, o iPhone volta para a internet de casa sem avisar. Antes de usar, confira o ícone \"VPN\" no topo do iPhone."))
                .font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Cor.linhaForte))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).vidro()
    }

    private var conexoes: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Conexões ativas").fontWeight(.semibold); Spacer(); Text("agora").font(.system(size: 12)).foregroundStyle(Cor.apagado) }
            if store.conexoes.isEmpty {
                Text("Nenhuma conexão na porta do celular.").font(.system(size: 13)).foregroundStyle(Cor.apagado)
            }
            ForEach(store.conexoes) { c in
                HStack {
                    Text(c.ip)
                    Spacer()
                    Text(c.ativa(agora: Date()) ? "ativa agora" : "vista há pouco").font(.system(size: 12)).foregroundStyle(Cor.apagado)
                }
                .font(.system(size: 13)).padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
            Text("O Mac vê conexões na porta do celular, não aparelhos verificados. Cada uma fica listada por 3 min depois da última atividade.")
                .font(.system(size: 11.5)).foregroundStyle(Cor.apagado).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).vidro()
    }
}
