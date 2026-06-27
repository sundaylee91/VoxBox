import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onGoHome: () -> Void

    @EnvironmentObject var serverManager: ServerManager
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange, .orange.opacity(0.2))

            Text(L10n.somethingWrong)
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
                        Text(L10n.installPython)
                            .font(.caption).foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }

            // ── Action Buttons ──
            HStack(spacing: 12) {
                Button { onGoHome() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "house")
                        Text(L10n.home)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .help(L10n.goBackHome)

                Button { onRetry() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(L10n.retry)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .help(L10n.tryAgain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showDetails ? "eye.slash" : "eye")
                        Text(showDetails ? L10n.hide : L10n.details)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .help(L10n.showHideDetails)
            }

            // ── Expandable Details Panel ──
            if showDetails {
                VStack(alignment: .leading, spacing: 10) {
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

                    HStack(spacing: 8) {
                        Button {
                            serverManager.copyLogs()
                        } label: {
                            Label(L10n.copyLogs, systemImage: "doc.on.doc")
                                .font(.caption)
                        }

                        Button {
                            if let url = URL(string: "https://github.com/sundaylee91/VoxBox/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label(L10n.reportIssue, systemImage: "bubble.left")
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
