import AppKit
import SwiftUI
import VPNCore

struct LogsView: View {
    let store: StatusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Logs").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Atualizar") { Task { await store.carregarLogs() } }.buttonStyle(BotaoVidro())
                Button("Copiar tudo") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.log.joined(separator: "\n"), forType: .string)
                }
                .buttonStyle(BotaoVidro())
            }
            ScrollView {
                Text(store.log.isEmpty ? "Sem registros ainda." : store.log.joined(separator: "\n"))
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Cor.apagado)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .defaultScrollAnchor(.bottom)
            .vidro(raio: 14)
        }
        .padding(.top, 48).padding(.horizontal, 28).padding(.bottom, 24)
    }
}
