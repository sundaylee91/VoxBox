import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var serverManager: ServerManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VoxBox").font(.headline)
                Spacer()
                StatusDot(status: serverManager.status)
            }
            .padding(.horizontal, 12).padding(.top, 8)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Status: \(statusText)").font(.system(size: 12)).foregroundColor(.secondary)
                switch serverManager.status {
                case .running(let port), .warmingUp(let port):
                    Text("Port: \(port)").font(.system(size: 12)).foregroundColor(.secondary)
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            Group {
                if case .stopped = serverManager.status { Button("Start Server") { serverManager.start() } }
                if case .error = serverManager.status { Button("Retry") { serverManager.start() } }
                if case .running = serverManager.status {
                    Button("Open VoxBox") { serverManager.openInBrowser() }
                    Button("Restart Server") { serverManager.restart() }
                    Button("Stop Server") { serverManager.stop() }
                }
                if case .warmingUp = serverManager.status {
                    Button("Stop Server") { serverManager.stop() }
                }
                if case .starting = serverManager.status { Button("Stop") { serverManager.stop() } }
                if case .downloading = serverManager.status { Button("Cancel Download") { serverManager.stop() } }
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            Button("Quit VoxBox") { serverManager.stop(); NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q").padding(.horizontal, 12).padding(.bottom, 8)
        }
        .frame(width: 220)
    }
    
    private var statusText: String {
        switch serverManager.status {
        case .stopped: return "Stopped"
        case .starting: return "Starting…"
        case .warmingUp: return "Warming up…"
        case .downloading(let p): return "Downloading \(Int(p * 100))%"
        case .running: return "Running"
        case .error: return "Error"
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
