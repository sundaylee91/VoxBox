import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("preferredPort") private var preferredPort: Int = 8650
    @AppStorage("modelDirectory") private var modelDirectory: String = ""
    @AppStorage("autoStartServer") private var autoStartServer: Bool = true
    @AppStorage("splitBaseLM") private var splitBaseLM: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State private var showingLogs = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsSection(title: "Server", icon: "server.rack") {
                        Toggle(isOn: $autoStartServer) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-start server on launch")
                                Text("Server will start automatically when VoxBox opens").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Server port")
                                Text("Default: 8650").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            TextField("Port", value: $preferredPort, format: .number).textFieldStyle(.roundedBorder).frame(width: 100)
                                .onChange(of: preferredPort) { _, newValue in
                                    if newValue < 1024 { preferredPort = 1024 }
                                    if newValue > 65535 { preferredPort = 65535 }
                                }
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Model directory").font(.subheadline)
                            HStack {
                                TextField("Default: ~/Library/Application Support/VoxBox/models", text: $modelDirectory).textFieldStyle(.roundedBorder)
                                Button("Browse…") { browseModelDirectory() }.buttonStyle(.bordered)
                            }
                        }
                    }
                    
                    SettingsSection(title: "Performance", icon: "cpu") {
                        Toggle(isOn: $splitBaseLM) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Split Base LM")
                                Text("Reduces memory usage (~2GB less). Recommended for 8GB Macs.").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    SettingsSection(title: "General", icon: "gearshape") {
                        Toggle(isOn: $launchAtLogin) {
                            Text("Launch at login")
                        }
                        .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(enabled: newValue) }
                    }
                    
                    SettingsSection(title: "Logs", icon: "doc.text") {
                        HStack {
                            Button("Show Server Logs") { showingLogs.toggle() }.buttonStyle(.bordered)
                            Button("Copy Logs") { serverManager.copyLogs() }.buttonStyle(.bordered)
                        }
                        if showingLogs {
                            ScrollView {
                                Text(serverManager.logOutput.isEmpty ? "No logs yet…" : serverManager.logOutput)
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            }
                            .frame(height: 200).background(Color(nsColor: .textBackgroundColor)).cornerRadius(6)
                        }
                    }
                    
                    SettingsSection(title: "About", icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VoxBox").font(.headline)
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")").foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                Link("GitHub", destination: URL(string: "https://github.com/sundaylee91/VoxBox")!)
                                Link("VoxCPMANE", destination: URL(string: "https://github.com/0seba/VoxCPMANE")!)
                            }.font(.caption).padding(.top, 4)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 560)
    }
    
    private func browseModelDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "Select Model Directory"
        if panel.runModal() == .OK { modelDirectory = panel.url?.path ?? "" }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { print("⚠️ Failed to update login item: \(error)") }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String; let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(.accentColor)
                Text(title).font(.headline)
            }
            VStack(alignment: .leading, spacing: 12) { content() }.padding(.leading, 24)
        }
    }
}
