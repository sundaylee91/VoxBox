import SwiftUI

/// 🎤 VoxBox — Native macOS TTS app powered by VoxCPM2 + Apple Neural Engine
@main
struct VoxBoxApp: App {
    @StateObject private var serverManager = ServerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverManager)
                .frame(minWidth: 960, idealWidth: 1100, maxWidth: .infinity,
                       minHeight: 680, idealHeight: 780, maxHeight: .infinity)
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "autoStartServer") {
                        serverManager.start()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    serverManager.stop()
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About VoxBox") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "VoxBox",
                            .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                            .credits: NSAttributedString(string: "Powered by VoxCPM2 + Apple Neural Engine.\nOriginal VoxCPMANE by @0seba.", attributes: [:])
                        ]
                    )
                }
            }
            CommandGroup(replacing: .help) {
                Button("VoxCPMANE on GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/0seba/VoxCPMANE")!)
                }
                Button("VoxBox on GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sundaylee91/VoxBox")!)
                }
            }
        }
        
        MenuBarExtra("VoxBox", systemImage: menuBarIcon) {
            MenuBarView().environmentObject(serverManager)
        }
    }
    
    private var menuBarIcon: String {
        switch serverManager.status {
        case .running: return "waveform.circle.fill"
        case .starting, .downloading, .warmingUp: return "arrow.triangle.2.circlepath.circle"
        case .stopped: return "waveform.circle"
        case .error: return "exclamationmark.circle"
        }
    }
}
