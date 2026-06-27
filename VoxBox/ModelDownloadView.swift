import SwiftUI

struct ModelDownloadView: View {
    let progress: Double
    @EnvironmentObject var serverManager: ServerManager
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var startTime = Date()
    private let totalSizeGB: Double = 3.2

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue, .blue.opacity(0.2))
                .symbolEffect(.bounce, value: progress)

            VStack(spacing: 8) {
                Text(L10n.downloadingModels).font(.title2).fontWeight(.semibold)
                Text(L10n.downloadSubtitle)
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear).frame(width: 320).tint(.blue)

                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundColor(.blue)
                    Spacer()
                    Text("\(String(format: "%.1f", progress * totalSizeGB)) / \(String(format: "%.1f", totalSizeGB)) GB")
                        .font(.system(size: 14, design: .monospaced)).foregroundColor(.secondary)
                }
                .frame(width: 320)

                if progress > 0.01 {
                    Text(estimatedTimeRemaining).font(.caption).foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.caption)
                Text(L10n.oneTimeDownload).font(.caption)
            }
            .foregroundColor(.secondary).padding(.horizontal, 40)

            Spacer()

            Button(role: .cancel) { serverManager.stop() } label: {
                Text(L10n.cancel).frame(width: 80)
            }
            .buttonStyle(.bordered).padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var estimatedTimeRemaining: String {
        let elapsed = Date().timeIntervalSince(startTime)
        guard progress > 0 else { return "Calculating…" }
        let totalTime = elapsed / progress
        let remaining = totalTime - elapsed
        if remaining < 60 { return "~ \(Int(remaining)) seconds remaining" }
        else if remaining < 3600 { return "~ \(Int(remaining / 60)) minutes remaining" }
        else { return "~ \(String(format: "%.1f", remaining / 3600)) hours remaining" }
    }
}
