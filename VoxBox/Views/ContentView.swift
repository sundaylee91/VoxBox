import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: ServerManager
    @State private var windowScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color(.windowBackgroundColor)
                    .ignoresSafeArea()
                
                switch manager.status {
                case .idle, .starting:
                    VStack(spacing: 24) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Starting server…")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 400, height: 300)
                    
                case .warmingUp(let port):
                    WarmingUpView(port: port, manager: manager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .running(let port):
                    WebViewContainer(
                        port: port,
                        onSaveRequested: {
                            manager.saveAudioWithPanel()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .error(let message):
                    ErrorView(message: message, manager: manager)
                        .frame(width: 400, height: 300)
                }
            }
            .frame(
                width: AppDelegate.defaultWindowSize.width * windowScale,
                height: AppDelegate.defaultWindowSize.height * windowScale
            )
            .onAppear {
                updateScale(for: geo)
            }
            .onChange(of: geo.size) { newSize in
                updateScale(for: geo)
            }
        }
    }
    
    private func updateScale(for geo: GeometryProxy) {
        let baseWidth = AppDelegate.defaultWindowSize.width
        let scale = geo.size.width / baseWidth
        windowScale = max(0.7, min(scale, 2.0))
    }
}

// MARK: - WebView Container

struct WebViewContainer: View {
    let port: Int
    let onSaveRequested: () -> Void
    
    var body: some View {
        WebView(
            url: URL(string: "http://127.0.0.1:\(port)")!,
            onAudioCaptured: { data, text in
                ServerManager.shared.lastAudioData = data
                ServerManager.shared.lastAudioText = text
            },
            onSaveRequested: {
                onSaveRequested()
            }
        )
        .ignoresSafeArea()
    }
}

// MARK: - Warming Up View

struct WarmingUpView: View {
    let port: Int
    @ObservedObject var manager: ServerManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            ProgressView()
                .scaleEffect(0.8)
            Text("Warming up models…")
                .font(.title3)
                .fontWeight(.medium)
            Text("First launch may take 15-30 seconds while\nthe voice models are loaded into memory.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 420, height: 280)
        .onAppear {
            manager.probeWithRetry(port: port, maxAttempts: 60)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    @ObservedObject var manager: ServerManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.red)
            Text("Server Error")
                .font(.title3)
                .fontWeight(.medium)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button("Retry") {
                    manager.start()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(width: 420, height: 280)
    }
}
