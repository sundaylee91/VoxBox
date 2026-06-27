import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56)).foregroundStyle(.orange, .orange.opacity(0.2))
            
            Text("Something went wrong").font(.title2).fontWeight(.semibold)
            
            VStack(spacing: 6) {
                Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
                if message.contains("Python") {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal").font(.caption)
                        Text("Install Python: brew install python@3.12").font(.caption).foregroundColor(.blue)
                    }.padding(.top, 4)
                }
            }
            
            HStack(spacing: 12) {
                Button { onRetry() } label: {
                    HStack(spacing: 6) { Image(systemName: "arrow.clockwise"); Text("Retry") }
                        .padding(.horizontal, 24).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent)
                
                Button {
                    if let url = URL(string: "https://github.com/sundaylee91/VoxBox/issues") { NSWorkspace.shared.open(url) }
                } label: {
                    HStack(spacing: 6) { Image(systemName: "bubble.left"); Text("Report Issue") }
                        .padding(.horizontal, 24).padding(.vertical, 10)
                }.buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
