import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var serverManager: ServerManager
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.voxBox).font(.headline)
                Spacer()
                StatusDot(status: serverManager.status)
            }
            .padding(.horizontal, 12).padding(.top, 8)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(L10n.status): \(statusText)").font(.system(size: 12)).foregroundColor(.secondary)
                switch serverManager.status {
                case .running(let port), .warmingUp(let port):
                    Text("\(L10n.port): \(port)").font(.system(size: 12)).foregroundColor(.secondary)
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)

            Divider()

            Group {
                if case .stopped = serverManager.status {
                    Button(L10n.startServer) { serverManager.start() }
                }
                if case .error = serverManager.status {
                    Button(L10n.retry) { serverManager.start() }
                }
                if case .running = serverManager.status {
                    Button(L10n.openVoxBox) { serverManager.openInBrowser() }

                    // Save Last Audio — always visible when running
                    Button(L10n.saveLastAudio) {
                        serverManager.saveAudio(format: serverManager.preferredFormat)
                    }
                    .disabled(serverManager.audioHistory.isEmpty)

                    // Download History submenu
                    if !serverManager.audioHistory.isEmpty {
                        Menu(L10n.downloadHistory) {
                            ForEach(Array(serverManager.audioHistory.reversed().enumerated()), id: \.element.id) { idx, clip in
                                let actualIndex = serverManager.audioHistory.count - 1 - idx
                                let label = clip.text.isEmpty ? "Untitled" : String(clip.text.prefix(40))
                                Button("🎵 \(label)") {
                                    serverManager.saveAudio(historyIndex: actualIndex)
                                }
                            }
                        }
                    }

                    Button(L10n.restartServer) { serverManager.restart() }
                    Button(L10n.stopServer) { serverManager.stop() }
                }
                if case .warmingUp = serverManager.status {
                    Button(L10n.stopServer) { serverManager.stop() }
                }
                if case .starting = serverManager.status {
                    Button(L10n.stopAction) { serverManager.stop() }
                }
                if case .downloading = serverManager.status {
                    Button(L10n.cancelDownload) { serverManager.stop() }
                }
            }
            .padding(.horizontal, 12)

            Divider()

            Button(L10n.quit) { serverManager.stop(); NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q").padding(.horizontal, 12).padding(.bottom, 8)
        }
        .frame(width: 240)
    }

    private var statusText: String {
        switch serverManager.status {
        case .stopped: return L10n.statusStopped
        case .starting: return L10n.statusStarting
        case .warmingUp: return L10n.statusWarmingUp
        case .downloading(let p): return L10n.downloadingPct(Int(p * 100))
        case .running: return L10n.statusRunning
        case .error: return L10n.statusError
        }
    }
}

struct StatusDot: View {
    let status: ServerManager.ServerStatus

    var body: some View {
        Circle()
            .fill(color).frame(width: 8, height: 8)
            .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 3).scaleEffect(pulsing ? 1.8 : 1.0).opacity(pulsing ? 0.0 : 0.6))
            .animation(pulsing ? .easeInOut(duration: 1.2).repeatForever(autoreverses: false) : .default, value: pulsing)
    }

    private var color: Color {
        switch status {
        case .running: return .green
        case .starting, .downloading, .warmingUp: return .orange
        case .stopped: return .gray
        case .error: return .red
        }
    }

    private var pulsing: Bool {
        switch status { case .starting, .downloading, .warmingUp: return true; default: return false }
    }
}
