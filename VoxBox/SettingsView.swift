import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var serverManager: ServerManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared

    @AppStorage("preferredPort") private var preferredPort: Int = 8650
    @AppStorage("modelDirectory") private var modelDirectory: String = ""
    @AppStorage("autoStartServer") private var autoStartServer: Bool = true
    @AppStorage("splitBaseLM") private var splitBaseLM: Bool = false
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @State private var showingLogs = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.settings).font(.title2).fontWeight(.semibold)
                Spacer()
                Button(L10n.done) { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ── Language ──
                    SettingsSection(title: L10n.settingsLanguage, icon: "globe") {
                        VStack(alignment: .leading, spacing: 2) {
                            Picker(L10n.languageLabel, selection: $loc.language) {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.radioGroup)
                            Text(L10n.languageDesc)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }

                    // ── Server ──
                    SettingsSection(title: L10n.settingsServer, icon: "server.rack") {
                        Toggle(isOn: $autoStartServer) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.autoStartServer)
                                Text(L10n.autoStartDesc).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.serverPort)
                                Text(L10n.defaultPort).font(.caption).foregroundColor(.secondary)
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
                            Text(L10n.modelDirectory).font(.subheadline)
                            HStack {
                                TextField(L10n.defaultModelPath, text: $modelDirectory).textFieldStyle(.roundedBorder)
                                Button(L10n.browse) { browseModelDirectory() }.buttonStyle(.bordered)
                            }
                        }
                    }

                    // ── Performance ──
                    SettingsSection(title: L10n.settingsPerformance, icon: "cpu") {
                        Toggle(isOn: $splitBaseLM) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.splitBaseLM)
                                Text(L10n.splitBaseLMDesc).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }

                    // ── General ──
                    SettingsSection(title: L10n.settingsGeneral, icon: "gearshape") {
                        Toggle(isOn: $launchAtLogin) {
                            Text(L10n.launchAtLogin)
                        }
                        .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(enabled: newValue) }
                    }

                    // ── Logs ──
                    SettingsSection(title: L10n.settingsLogs, icon: "doc.text") {
                        HStack {
                            Button(L10n.showServerLogs) { showingLogs.toggle() }.buttonStyle(.bordered)
                            Button(L10n.copyLogs) { serverManager.copyLogs() }.buttonStyle(.bordered)
                        }
                        if showingLogs {
                            ScrollView {
                                Text(serverManager.logOutput.isEmpty ? L10n.noLogs : serverManager.logOutput)
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            }
                            .frame(height: 200).background(Color(nsColor: .textBackgroundColor)).cornerRadius(6)
                        }
                    }

                    // ── About ──
                    SettingsSection(title: L10n.about, icon: "info.circle") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.voxBox).font(.headline)
                            Text("\(L10n.version) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")").foregroundColor(.secondary)
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
        .frame(width: 520, height: 600)
    }

    private func browseModelDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = L10n.selectModelDir
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
