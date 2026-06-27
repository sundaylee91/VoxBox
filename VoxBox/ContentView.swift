import SwiftUI

struct ContentView: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
            
            Group {
                switch serverManager.status {
                case .stopped: LaunchView()
                case .starting: LoadingView(message: "Starting Python backend…")
                case .downloading(let progress): ModelDownloadView(progress: progress)
                case .running: WebView(url: URL(string: "http://127.0.0.1:\(serverManager.port)")!)
                case .error(let message): ErrorView(message: message) { serverManager.start() }
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    StatusBadge(status: serverManager.status)
                    Button { showSettings.toggle() } label: {
                        Image(systemName: "gearshape").font(.system(size: 14))
                    }
                    .buttonStyle(.plain).padding(.trailing, 8).help("Settings")
                }
                .padding(.top, 8).padding(.horizontal, 12)
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(serverManager)
        }
    }
}

struct StatusBadge: View {
    let status: ServerManager.ServerStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 8, height: 8)
            Text(statusLabel).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .quaternaryLabelColor)))
    }
    
    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .starting, .downloading: return .orange
        case .stopped: return .gray
        case .error: return .red
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .running: return "Running"
        case .starting: return "Starting…"
        case .downloading(let p): return "Downloading \(Int(p * 100))%"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }
}
