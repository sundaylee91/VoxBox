//
//  Views/ContentView.swift
//  VoxBox
//
//  NOTE: This file is not compiled — the active ContentView is at VoxBox/ContentView.swift.
//  Kept as reference only.
//

import SwiftUI

struct ContentView_Reference: View {
    @EnvironmentObject var serverManager: ServerManager
    @State private var showSettings = false

    var body: some View {
        ZStack {
            if case .running = serverManager.status {
                WebView(
                    url: URL(string: "http://127.0.0.1:\(serverManager.port)")!,
                    onAudioCaptured: { data, text in
                        serverManager.lastAudioData = data
                        serverManager.lastAudioText = text
                    },
                    onSaveRequested: {
                        serverManager.saveAudio()
                    }
                )
            }
        }
    }
}
