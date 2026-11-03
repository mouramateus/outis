import AppKit
import SwiftUI
import UserNotifications
import VPNCore

/// Caminho do CLI: embutido no app; `VPN_CLI` só para desenvolvimento.
func caminhoDoCLI() -> URL {
    if let v = ProcessInfo.processInfo.environment["VPN_CLI"] { return URL(fileURLWithPath: v) }
    return Bundle.main.resourceURL?.appendingPathComponent("cli/vpn") ?? URL(fileURLWithPath: "vpn")
}

@MainActor enum Modelo {
    static let store = StatusStore(cli: VPNCLI(executavel: caminhoDoCLI()), notificar: { _, motivo in
        Notificacoes.avisar(motivo)
    })
}

enum Notificacoes {
    static let categoria = "queda"
    static let religar = "religar"

    static func preparar(delegate: UNUserNotificationCenterDelegate) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let c = UNUserNotificationCenter.current()
        c.delegate = delegate
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let botao = UNNotificationAction(identifier: religar, title: "Religar nesta rede", options: [.foreground])
        c.setNotificationCategories([UNNotificationCategory(identifier: categoria, actions: [botao], intentIdentifiers: [])])
    }

    static func avisar(_ texto: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let n = UNMutableNotificationContent()
        n.title = "VPN País"
        n.body = texto
        n.categoryIdentifier = categoria
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: n, trigger: nil))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Notificacoes.preparar(delegate: self)
        Task { @MainActor in Modelo.store.iniciar() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in await Modelo.store.atualizar() }
        }
    }

    // Fechar a janela não encerra: o ícone da barra continua. Sair (⌘Q) não desliga a VPN.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == Notificacoes.religar else { return }
        await Modelo.store.ligar()
    }
}

@main
struct VPNPaisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = Modelo.store

    var body: some Scene {
        Window("VPN País", id: "principal") {
            MainView(store: store)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 640)
        .commands { CommandGroup(replacing: .newItem) {} }

        MenuBarExtra {
            MenuRapidoView(store: store)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarIcon(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
