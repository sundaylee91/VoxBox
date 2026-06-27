import SwiftUI

struct LoadingView: View {
    let message: String
    @State private var isAnimating = false
    
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
                Text(message).font(.headline)
                Text("This may take a moment on first launch…").font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
