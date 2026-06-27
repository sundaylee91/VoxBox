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
                case .stopped:
                    LaunchView()
                case .starting:
                    LoadingView(message: "Starting Python backend…")
                case .downloading(let progress):
                    ModelDownloadView(progress: progress)
                case .warmingUp(let port):
                    WarmingUpView(port: port)
                case .running:
                    ZStack(alignment: .bottom) {
                        WebView(
                            url: URL(string: "http://127.0.0.1:\(serverManager.port)")!,
                            onAudioCaptured: { data, text in
                                serverManager.lastAudioData = data
                                serverManager.lastAudioText = text
                            }
                        )
                        
                        // ── Persistent save bar ──
                        SaveAudioBar(
                            audioText: serverManager.lastAudioText,
                            hasAudio: serverManager.lastAudioData != nil,
                            selectedFormat: $serverManager.preferredFormat,
                            onSave: { format in
                                serverManager.saveAudio(format: format)
                            }
                        )
                    }
                case .error(let message):
                    ErrorView(
                        message: message,
                        onRetry: { serverManager.start() },
                        onGoHome: { serverManager.status = .stopped }
                    )
                    .environmentObject(serverManager)
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
        .onReceive(NotificationCenter.default.publisher(for: .saveAudio)) { _ in
            guard serverManager.lastAudioData != nil else { return }
            serverManager.saveAudio(format: serverManager.preferredFormat)
        }
    }
}

// MARK: - Save Audio Bar (persistent)

struct SaveAudioBar: View {
    let audioText: String?
    let hasAudio: Bool
    @Binding var selectedFormat: AudioFormat
    let onSave: (AudioFormat) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: hasAudio ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 18))
                .foregroundColor(hasAudio ? .green : .secondary)
            
            // Text preview or placeholder
            if let text = audioText, !text.isEmpty {
                Text(text.prefix(60) + (text.count > 60 ? "…" : ""))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("Generate audio in the web UI above")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Format picker
            Picker("Format", selection: $selectedFormat) {
                Text("WAV").tag(AudioFormat.wav)
                Text("MP3").tag(AudioFormat.mp3)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            .disabled(!hasAudio)
            
            // Save button
            Button("Save to Mac…") {
                onSave(selectedFormat)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!hasAudio)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let saveAudio = Notification.Name("VoxBox.saveAudio")
}

// MARK: - Warming Up View

struct WarmingUpView: View {
    let port: Int
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
                Text("Server is warming up\(String(repeating: ".", count: dots))")
                    .font(.headline)
                    .onReceive(timer) { _ in dots = (dots + 1) % 4 }
                Text("Loading CoreML models into Neural Engine…")
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
        case .starting, .downloading, .warmingUp: return .orange
        case .stopped: return .gray
        case .error: return .red
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .running: return "Running"
        case .starting: return "Starting…"
        case .warmingUp: return "Warming up…"
        case .downloading(let p): return "Downloading \(Int(p * 100))%"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }
}
