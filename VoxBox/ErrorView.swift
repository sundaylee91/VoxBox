import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onGoHome: () -> Void
    
    @EnvironmentObject var serverManager: ServerManager
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange, .orange.opacity(0.2))
            
            Text("Something went wrong")
                .font(.title2).fontWeight(.semibold)
            
            VStack(spacing: 6) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(showDetails ? nil : 3)
                
                if message.contains("Python") {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal").font(.caption)
                        Text("Install Python: brew install python@3.12")
                            .font(.caption).foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
            
            // ── Action Buttons ──────────────────────────────
            HStack(spacing: 12) {
                Button { onGoHome() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "house")
                        Text("Home")
                    }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .help("Go back to the home screen")
                
                Button { onRetry() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .help("Try starting the server again")
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showDetails ? "eye.slash" : "eye")
                        Text(showDetails ? "Hide" : "Details")
                    }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .help("Show or hide detailed error information")
            }
            
            // ── Expandable Details Panel ────────────────────
            if showDetails {
                VStack(alignment: .leading, spacing: 10) {
                    // Error message detail
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ERROR MESSAGE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 160)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    }
                    
                    // Server log
                    if !serverManager.logOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SERVER LOG")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                Text(serverManager.logOutput)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                        }
                    }
                    
                    // Quick actions row
                    HStack(spacing: 8) {
                        Button {
                            serverManager.copyLogs()
                        } label: {
                            Label("Copy Logs", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        
                        Button {
                            if let url = URL(string: "https://github.com/sundaylee91/VoxBox/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Report Issue", systemImage: "bubble.left")
                                .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
