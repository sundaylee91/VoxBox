import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Conversion Error

enum ConversionError: LocalizedError {
    case noMP3Encoder
    case processFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noMP3Encoder:
            return "MP3 encoder not found. Please install ffmpeg (brew install ffmpeg) or save as M4A/WAV."
        case .processFailed(let tool):
            return "\(tool) conversion failed."
        }
    }
}

// MARK: - Server Manager

class ServerManager: ObservableObject {
    static let shared = ServerManager()
    
    enum Status: Equatable {
        case idle
        case starting
        case warmingUp(port: Int)
        case running(port: Int)
        case error(String)
    }
    
    @Published var status: Status = .idle
    
    var lastAudioData: Data?
    var lastAudioText: String?
    
    private var process: Process?
    private var port: Int = 0
    
    // MARK: - Start Server
    
    func start() {
        guard status != .starting, status != .warmingUp(port: port), status != .running(port: port) else {
            return
        }
        
        status = .starting
        port = findAvailablePort()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["kokoro", "-p", "\(self.port)"]
            task.currentDirectoryURL = NSHomeDirectory().appending(path: ".kokoro")
            
            let env = ProcessInfo.processInfo.environment
            var taskEnv = env
            let pathParts = [
                env["PATH"] ?? "",
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "\(NSHomeDirectory())/.pyenv/shims"
            ]
            taskEnv["PATH"] = pathParts.joined(separator: ":")
            task.environment = taskEnv
            
            do {
                try task.run()
                self.process = task
                
                // Read first few lines to detect server start
                DispatchQueue.global(qos: .background).async {
                    let handle = pipe.fileHandleForReading
                    var buffer = ""
                    var serverReady = false
                    
                    while task.isRunning {
                        let data = handle.availableData
                        if data.isEmpty { continue }
                        
                        if let str = String(data: data, encoding: .utf8) {
                            buffer += str
                            // Check for typical FastAPI/Uvicorn ready signals
                            if buffer.contains("Uvicorn running") ||
                               buffer.contains("Application startup complete") ||
                               buffer.contains("Serving") {
                                serverReady = true
                            }
                        }
                        
                        if serverReady {
                            DispatchQueue.main.async {
                                self.status = .warmingUp(port: self.port)
                            }
                            break
                        }
                    }
                }
                
                task.waitUntilExit()
                
                DispatchQueue.main.async {
                    if self.status != .idle && self.status != .error("") {
                        self.status = .error("Server process exited unexpectedly.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .error("Failed to start server: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Warmup Probe
    
    func probeWithRetry(port: Int, maxAttempts: Int) {
        probe(port: port, attempt: 1, maxAttempts: maxAttempts)
    }
    
    private func probe(port: Int, attempt: Int, maxAttempts: Int) {
        guard attempt <= maxAttempts else {
            DispatchQueue.main.async {
                self.status = .error("Server did not respond after \(maxAttempts) attempts.")
            }
            return
        }
        
        guard let url = URL(string: "http://127.0.0.1:\(port)/docs") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.status = .running(port: port)
                    print("[VoxBox] Server ready on port \(port)")
                } else {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self?.probe(port: port, attempt: attempt + 1, maxAttempts: maxAttempts)
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Stop Server
    
    func stop() {
        process?.terminate()
        process = nil
        status = .idle
        lastAudioData = nil
        lastAudioText = nil
    }
    
    // MARK: - Port Finding
    
    private func findAvailablePort() -> Int {
        // Try common ports
        for port in 8888...8900 {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            if sock < 0 { continue }
            defer { close(sock) }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(port).bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            if result == 0 {
                return port
            }
        }
        return 8765
    }
    
    // MARK: - Save Audio with Panel
    
    func saveAudioWithPanel() {
        guard let audioData = lastAudioData else {
            showAlert(message: "No audio generated yet.", info: "Generate audio in the web UI first, then click the download button.")
            return
        }
        
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            // Fallback: save directly to desktop
            saveAudioDirectly(audioData)
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Save Audio"
        panel.canCreateDirectories = true
        panel.showsTagField = true
        
        // Set default filename
        let baseName = sanitizeFileName(lastAudioText ?? "untitled")
        panel.nameFieldStringValue = baseName + ".wav"
        
        // Build allowed file types dynamically
        var allowedTypes: [UTType] = [.wav]
        
        // M4A always available via afconvert
        if let m4aType = UTType(filenameExtension: "m4a") {
            allowedTypes.append(m4aType)
        }
        
        // MP3 only if encoder available
        if mp3EncoderAvailable() {
            if let mp3Type = UTType(filenameExtension: "mp3") {
                allowedTypes.append(mp3Type)
            }
        }
        
        panel.allowedContentTypes = allowedTypes
        panel.allowsOtherFileTypes = false
        
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.saveAudioData(audioData, to: url)
        }
    }
    
    private func saveAudioDirectly(_ audioData: Data) {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let baseName = sanitizeFileName(lastAudioText ?? "untitled")
        let url = desktop.appendingPathComponent(baseName + ".wav")
        do {
            try audioData.write(to: url)
            print("[VoxBox] Saved to \(url.path)")
        } catch {
            print("[VoxBox] Save error: \(error)")
        }
    }
    
    private func saveAudioData(_ audioData: Data, to url: URL) {
        let ext = url.pathExtension.lowercased()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                switch ext {
                case "mp3":
                    try self?.convertToMP3(wavData: audioData, outputURL: url)
                case "m4a", "m4r":
                    try self?.convertToM4A(wavData: audioData, outputURL: url)
                default:
                    // WAV — write directly
                    try audioData.write(to: url)
                }
                
                DispatchQueue.main.async {
                    print("[VoxBox] Audio saved to \(url.path)")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showAlert(message: "Save failed.", info: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Format Conversion
    
    private func convertToM4A(wavData: Data, outputURL: URL) throws {
        let tempWAV = FileManager.default.temporaryDirectory.appendingPathComponent("voxbox_\(UUID().uuidString).wav")
        try wavData.write(to: tempWAV)
        defer { try? FileManager.default.removeItem(at: tempWAV) }
        
        // afconvert: M4A (AAC) — natively supported on macOS
        try runCommand(
            executable: "/usr/bin/afconvert",
            arguments: [
                "-f", "m4af",
                "-d", "aac ",
                tempWAV.path,
                outputURL.path
            ]
        )
    }
    
    private func convertToMP3(wavData: Data, outputURL: URL) throws {
        let tempWAV = FileManager.default.temporaryDirectory.appendingPathComponent("voxbox_\(UUID().uuidString).wav")
        try wavData.write(to: tempWAV)
        defer { try? FileManager.default.removeItem(at: tempWAV) }
        
        // Priority 1: ffmpeg
        if let ffmpeg = findExecutable("ffmpeg") {
            try runCommand(
                executable: ffmpeg,
                arguments: [
                    "-y",
                    "-i", tempWAV.path,
                    "-codec:a", "libmp3lame",
                    "-qscale:a", "2",
                    outputURL.path
                ]
            )
            return
        }
        
        // Priority 2: lame
        if let lame = findExecutable("lame") {
            try runCommand(
                executable: lame,
                arguments: [
                    "--preset", "standard",
                    tempWAV.path,
                    outputURL.path
                ]
            )
            return
        }
        
        throw ConversionError.noMP3Encoder
    }
    
    private func runCommand(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ConversionError.processFailed("\(executable): \(errorStr)")
        }
    }
    
    // MARK: - Utility
    
    private func findExecutable(_ name: String) -> String? {
        let paths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    func mp3EncoderAvailable() -> Bool {
        findExecutable("ffmpeg") != nil || findExecutable("lame") != nil
    }
    
    func availableFormatOptions() -> [String] {
        var formats = ["wav", "m4a"]
        if mp3EncoderAvailable() {
            formats.append("mp3")
        }
        return formats
    }
    
    private func sanitizeFileName(_ text: String) -> String {
        // Replace common issue characters
        var name = text
            .replacingOccurrences(of: ":", with: "：")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Truncate if too long
        if name.count > 100 {
            name = String(name.prefix(100))
        }
        
        if name.isEmpty {
            name = "untitled"
        }
        
        return name
    }
    
    private func showAlert(message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
