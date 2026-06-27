import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serverManager: ServerManager
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            Group {
                switch serverManager.status {
                case .stopped:
                    LaunchView()
                case .starting:
                    LoadingView(message: L10n.loadingPython)
                case .downloading(let progress):
                    ModelDownloadView(progress: progress)
                case .warmingUp(let port):
                    WarmingUpView(port: port)
                case .running:
                    WebView(
                        url: URL(string: "http://127.0.0.1:\(serverManager.port)")!,
                        onAudioCaptured: { data, text in
                            serverManager.captureAudio(data: data, text: text)
                        },
                        onSaveRequested: {
                            serverManager.saveAudio()
                        },
                        onSaveHistoryItem: { index in
                            serverManager.saveAudio(historyIndex: index)
                        }
                    )
                case .error(let message):
                    ErrorView(
                        message: message,
                        onRetry: { serverManager.start() },
                        onGoHome: { serverManager.status = .stopped }
                    )
                    .environmentObject(serverManager)
                }
            }

            // ── Status bar overlay (glass effect, visible on dark backgrounds) ──
            VStack {
                HStack {
                    Spacer()
                    StatusBadge(status: serverManager.status)
                    Button { showSettings.toggle() } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                    .help(L10n.settings)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                )
                .padding(.top, 8)
                .padding(.horizontal, 12)
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(serverManager)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let saveAudio = Notification.Name("VoxBox.saveAudio")
}

// MARK: - Warming Up View

struct WarmingUpView: View {
    let port: Int
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isAnimating = false
    @State private var dots = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle().stroke(Color.blue.opacity(0.15), lineWidth: 6).frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AngularGradient(colors: [.blue, .purple, .blue.opacity(0.5)], center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: isAnimating)
            }
            .onAppear { isAnimating = true }

            VStack(spacing: 8) {
                Text(L10n.serverWarmingUp(dots))
                    .font(.headline)
                    .onReceive(timer) { _ in dots = (dots + 1) % 4 }
                Text(L10n.loadingCoreML)
                    .font(.subheadline).foregroundColor(.secondary)
                Text("Port: \(port)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ServerManager.ServerStatus
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.08))
        )
    }

    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .starting, .downloading, .warmingUp: return .orange
        case .stopped: return .gray
        case .error: return .red
        }
    }

    private var statusLabel: String {
        switch status {
        case .running: return L10n.statusRunning
        case .starting: return L10n.statusStarting
        case .warmingUp: return L10n.statusWarmingUp
        case .downloading(let p): return L10n.downloadingPct(Int(p * 100))
        case .stopped: return L10n.statusStopped
        case .error: return L10n.statusError
        }
    }
}
