import SwiftUI

struct LaunchView: View {
    @EnvironmentObject var serverManager: ServerManager
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80)).foregroundStyle(.blue, .blue.opacity(0.15))
                .shadow(color: .blue.opacity(0.2), radius: 20)
            
            VStack(spacing: 12) {
                Text("VoxBox").font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Text-to-Speech & Voice Cloning on Apple Neural Engine")
                    .font(.title3).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            
            HStack(spacing: 32) {
                FeatureCard(icon: "text.bubble.fill", title: "Text to Speech", description: "Type any text and hear it spoken naturally")
                FeatureCard(icon: "person.wave.2.fill", title: "Voice Cloning", description: "Clone any voice from a 3-second audio sample")
                FeatureCard(icon: "bolt.fill", title: "Neural Engine", description: "Runs entirely on Apple Silicon, fully offline")
            }
            
            Button { serverManager.start() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Start VoxBox")
                }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.return)
            
            VStack(spacing: 4) {
                Text("On first launch, ~3.2GB of CoreML models will be downloaded.").font(.caption).foregroundColor(.secondary)
                Text("Requires Python 3.10–3.12 and Apple Silicon Mac.").font(.caption).foregroundColor(.secondary)
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
