import SwiftUI

struct LaunchView: View {
    @EnvironmentObject var serverManager: ServerManager
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80)).foregroundStyle(.blue, .blue.opacity(0.15))
                .shadow(color: .blue.opacity(0.2), radius: 20)

            VStack(spacing: 12) {
                Text(L10n.voxBox).font(.system(size: 36, weight: .bold, design: .rounded))
                Text(L10n.voxBoxSubtitle)
                    .font(.title3).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            HStack(spacing: 32) {
                FeatureCard(icon: "text.bubble.fill", title: L10n.featureTTS, description: L10n.featureTTSDesc)
                FeatureCard(icon: "person.wave.2.fill", title: L10n.featureClone, description: L10n.featureCloneDesc)
                FeatureCard(icon: "bolt.fill", title: L10n.featureANE, description: L10n.featureANEDesc)
            }

            Button { serverManager.start() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text(L10n.startVoxBox)
                }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.return)

            VStack(spacing: 4) {
                Text(L10n.firstLaunchNote).font(.caption).foregroundColor(.secondary)
                Text(L10n.requiresNote).font(.caption).foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureCard: View {
    let icon: String; let title: String; let description: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 28)).foregroundStyle(.blue)
                .frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.1)))
            Text(title).font(.headline)
            Text(description).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).frame(width: 140)
        }
    }
}
