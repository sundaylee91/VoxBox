import Foundation
import Combine
import AppKit

class ServerManager: ObservableObject {
    @Published var status: ServerStatus = .stopped
    @Published var port: Int = 8650
    @Published var downloadProgress: Double = 0.0
    @Published var logOutput: String = ""
    
    enum ServerStatus: Equatable {
        case stopped
        case starting
        case downloading(progress: Double)
        case running
        case error(String)
    }
    
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var healthTimer: Timer?
    private var outputBuffer: String = ""
    private let healthCheckInterval: TimeInterval = 2.0
    private let healthCheckTimeout: TimeInterval = 300.0
    private let healthCheckPath = "/docs"
    
    func findPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3.12", "/opt/homebrew/bin/python3.11", "/opt/homebrew/bin/python3.10",
            "/usr/local/bin/python3.12", "/usr/local/bin/python3.11", "/usr/local/bin/python3.10",
            "/usr/bin/python3",
            "\(NSHomeDirectory())/.pyenv/shims/python3",
            "/opt/homebrew/anaconda3/bin/python3", "/usr/local/anaconda3/bin/python3"
        ]
        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
            guard FileManager.default.isExecutableFile(atPath: url.path) else { continue }
            if let version = getPythonVersion(at: url.path), version >= (3, 10) && version < (3, 13) {
                log("✅ Found Python \(version.0).\(version.1) at \(candidate)")
                return candidate
            }
        }
        return nil
    }
    
    private func getPythonVersion(at path: String) -> (Int, Int)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe; process.standardError = pipe
        do {
            try process.run(); process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let pattern = /Python (\d+)\.(\d+)/
            if let match = output.firstMatch(of: pattern) {
                return (Int(match.1) ?? 0, Int(match.2) ?? 0)
            }
        } catch {
            log("⚠️ Failed to check Python version at \(path): \(error)")
        }
        return nil
    }
    
    func ensurePackageInstalled(pythonPath: String) -> Bool {
        log("📦 Checking voxcpmane2 installation…")
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: pythonPath)
        checkProcess.arguments = ["-c", "import voxcpmane"]
        checkProcess.standardOutput = Pipe(); checkProcess.standardError = Pipe()
        do {
            try checkProcess.run(); checkProcess.waitUntilExit()
            if checkProcess.terminationStatus == 0 { log("✅ voxcpmane2 already installed"); return true }
        } catch { log("⚠️ Import check failed, installing…") }
        
        log("📦 Installing voxcpmane2 via pip…")
        let installProcess = Process()
        installProcess.executableURL = URL(fileURLWithPath: pythonPath)
        installProcess.arguments = ["-m", "pip", "install", "--user", "voxcpmane2"]
        let pipe = Pipe()
        installProcess.standardOutput = pipe; installProcess.standardError = pipe
        do {
            try installProcess.run(); installProcess.waitUntilExit()
            if installProcess.terminationStatus == 0 { log("✅ voxcpmane2 installed successfully"); return true }
            else { log("❌ pip install failed"); return false }
        } catch { log("❌ pip install error: \(error)"); return false }
    }
    
    func start() {
        guard status == .stopped || status == .error("") else { return }
        status = .starting
        log("🚀 Starting VoxBox server…")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let pythonPath = self.findPython() else {
                DispatchQueue.main.async { self.status = .error("Python 3.10–3.12 not found.\nInstall via: brew install python@3.12") }
                return
            }
            guard self.ensurePackageInstalled(pythonPath: pythonPath) else {
                DispatchQueue.main.async { self.status = .error("Failed to install voxcpmane2. Check network and try again.") }
                return
            }
            let port = self.findAvailablePort(starting: UserDefaults.standard.integer(forKey: "preferredPort"))
            DispatchQueue.main.async { self.port = port }
            self.launchServer(pythonPath: pythonPath, port: port)
        }
    }
    
    private func launchServer(pythonPath: String, port: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        var args = ["-m", "voxcpmane.server", "--host", "127.0.0.1", "--port", "\(port)"]
        if let modelDir = UserDefaults.standard.string(forKey: "modelDirectory"), !modelDir.isEmpty {
            args.append(contentsOf: ["--model-dir", modelDir])
        }
        if UserDefaults.standard.bool(forKey: "splitBaseLM") { args.append("--split-base-lm") }
        process.arguments = args
        
        let outputPipe = Pipe(); let errorPipe = Pipe()
        process.standardOutput = outputPipe; process.standardError = errorPipe
        self.outputPipe = outputPipe; self.errorPipe = errorPipe; self.process = process
        
        setupOutputMonitoring(outputPipe: outputPipe)
        setupOutputMonitoring(outputPipe: errorPipe)
        
        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.healthTimer?.invalidate(); self.healthTimer = nil
                if proc.terminationStatus != 0 && self.status != .stopped {
                    self.status = .error("Server exited unexpectedly (code \(proc.terminationStatus)).")
                } else if self.status != .stopped { self.status = .stopped }
            }
        }
        
        do {
            try process.run()
            log("🟢 Server process started (PID: \(process.processIdentifier))")
            DispatchQueue.main.async { [weak self] in self?.startHealthCheck() }
        } catch {
            log("❌ Failed to launch server: \(error)")
            DispatchQueue.main.async { self.status = .error("Failed to launch Python server:\n\(error.localizedDescription)") }
        }
    }
    
    func stop() {
        log("🛑 Stopping server…")
        healthTimer?.invalidate(); healthTimer = nil
        guard let process = process, process.isRunning else { status = .stopped; return }
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, let proc = self.process, proc.isRunning else { return }
            proc.interrupt()
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { if proc.isRunning { proc.forceTerminate() } }
        }
        self.process = nil
        status = .stopped
    }
    
    func restart() { stop(); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.start() } }
    
    private func startHealthCheck() {
        let startTime = Date()
        healthTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if Date().timeIntervalSince(startTime) > self.healthCheckTimeout {
                timer.invalidate()
                DispatchQueue.main.async { if case .starting = self.status { self.status = .error("Server took too long to start.") } }
                return
            }
            self.checkHealth()
        }
    }
    
    private func checkHealth() {
        guard let url = URL(string: "http://127.0.0.1:\(port)\(healthCheckPath)") else { return }
        var request = URLRequest(url: url); request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if case .starting = self.status { self.status = .running; self.healthTimer?.invalidate(); self.healthTimer = nil }
                }
            }
        }.resume()
    }
    
    private func setupOutputMonitoring(outputPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self, let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty else { return }
            DispatchQueue.main.async {
                self.outputBuffer += output
                self.logOutput = String(self.outputBuffer.suffix(10000))
                self.parseProgress(from: output)
            }
        }
    }
    
    private func parseProgress(from line: String) {
        let pattern = /(\d+)%/
        if let match = line.firstMatch(of: pattern), let percent = Int(match.1) {
            let progress = Double(percent) / 100.0
            DispatchQueue.main.async {
                if case .starting = self.status { self.status = .downloading(progress: progress) }
                else if case .downloading = self.status { self.status = .downloading(progress: progress) }
                self.downloadProgress = progress
            }
        }
    }
    
    private func findAvailablePort(starting port: Int) -> Int {
        var port = max(port, 1024)
        for _ in 0..<100 { if isPortAvailable(port: port) { return port }; port += 1 }
        return 8650
    }
    
    private func isPortAvailable(port: Int) -> Bool {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { Darwin.close(socket) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        } == 0
    }
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)"
        print(line)
        DispatchQueue.main.async { [weak self] in
            self?.outputBuffer += line + "\n"
            self?.logOutput = String(self?.outputBuffer.suffix(10000) ?? "")
        }
    }
    
    func openInBrowser() {
        if let url = URL(string: "http://127.0.0.1:\(port)") { NSWorkspace.shared.open(url) }
    }
    
    func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logOutput, forType: .string)
    }
}
