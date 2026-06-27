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
    
    // MARK: - Paths
    
    /// Dedicated virtual environment inside App Support — isolates us from system Python restrictions.
    private var venvPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("VoxBox/venv").path
    }
    
    private var venvPython: String {
        return (venvPath as NSString).appendingPathComponent("bin/python3")
    }
    
    // MARK: - Python Detection
    
    /// Find a system Python 3.10–3.12 to bootstrap the venv.
    func findSystemPython() -> String? {
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
    
    // MARK: - Virtual Environment Setup
    
    /// Ensure an isolated venv exists with voxcpmane2 installed.
    /// Returns the venv's python3 path on success, nil on failure.
    func setupVenv(systemPython: String) -> String? {
        let fm = FileManager.default
        let venvPythonPath = self.venvPython
        
        // ── 1. Create venv if missing ──────────────────────────────
        if !fm.fileExists(atPath: venvPythonPath) {
            log("🐍 Creating virtual environment at \(venvPath)…")
            let create = Process()
            create.executableURL = URL(fileURLWithPath: systemPython)
            create.arguments = ["-m", "venv", venvPath]
            let pipe = Pipe()
            create.standardOutput = pipe; create.standardError = pipe
            do {
                try create.run(); create.waitUntilExit()
                if create.terminationStatus != 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let err = String(data: data, encoding: .utf8) ?? "(no output)"
                    log("❌ venv creation failed:\n\(err)")
                    return nil
                }
                log("✅ Virtual environment created")
            } catch {
                log("❌ venv creation error: \(error.localizedDescription)")
                return nil
            }
        } else {
            log("📁 Using existing venv at \(venvPath)")
        }
        
        // ── 2. Upgrade pip inside the venv ────────────────────────
        log("📦 Upgrading pip in venv…")
        let upgradePip = runPythonInVenv(args: ["-m", "pip", "install", "--upgrade", "pip", "--quiet"])
        if !upgradePip.success {
            log("⚠️ pip upgrade had issues (continuing anyway):\n\(upgradePip.output.prefix(500))")
        }
        
        // ── 3. Check if voxcpmane2 is already installed ───────────
        let check = runPythonInVenv(args: ["-c", "import voxcpmane; print('ok')"])
        if check.success && check.output.contains("ok") {
            log("✅ voxcpmane2 already installed in venv")
            return venvPythonPath
        }
        
        // ── 4. Install voxcpmane2 ─────────────────────────────────
        log("📦 Installing voxcpmane2 in venv (this may take a minute)…")
        let install = runPythonInVenv(args: ["-m", "pip", "install", "voxcpmane2"])
        if install.success {
            log("✅ voxcpmane2 installed successfully")
            return venvPythonPath
        }
        
        // ── 5. Fallback: try with --pre (pre-release) ─────────────
        log("⚠️ Stable install failed, trying pre-release…")
        let installPre = runPythonInVenv(args: ["-m", "pip", "install", "--pre", "voxcpmane2"])
        if installPre.success {
            log("✅ voxcpmane2 pre-release installed")
            return venvPythonPath
        }
        
        log("❌ All installation attempts failed:\n\(install.output.prefix(1000))")
        return nil
    }
    
    /// Run a command using the venv's python3. Returns (success, combined stdout+stderr).
    private func runPythonInVenv(args: [String]) -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: venvPython)
        process.arguments = args
        // Merge stderr into stdout so we capture error details
        let pipe = Pipe()
        process.standardOutput = pipe; process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    // MARK: - Server Lifecycle
    
    func start() {
        guard status == .stopped || status == .error("") else { return }
        status = .starting
        log("🚀 Starting VoxBox server…")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Find system Python
            guard let systemPython = self.findSystemPython() else {
                DispatchQueue.main.async {
                    self.status = .error(
                        "Python 3.10–3.12 not found.\n\nInstall via Homebrew:\n  brew install python@3.12"
                    )
                }
                return
            }
            
            // 2. Set up isolated venv + install voxcpmane2
            guard let venvPy = self.setupVenv(systemPython: systemPython) else {
                DispatchQueue.main.async {
                    self.status = .error(
                        "Failed to install voxcpmane2.\n\nCheck the logs for details and ensure you have an internet connection."
                    )
                }
                return
            }
            
            // 3. Pick a free port
            let port = self.findAvailablePort(
                starting: UserDefaults.standard.integer(forKey: "preferredPort")
            )
            DispatchQueue.main.async { self.port = port }
            
            // 4. Launch!
            self.launchServer(venvPython: venvPy, port: port)
        }
    }
    
    private func launchServer(venvPython: String, port: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: venvPython)
        var args = ["-m", "voxcpmane.server", "--host", "127.0.0.1", "--port", "\(port)"]
        
        if let modelDir = UserDefaults.standard.string(forKey: "modelDirectory"), !modelDir.isEmpty {
            args.append(contentsOf: ["--model-dir", modelDir])
        }
        if UserDefaults.standard.bool(forKey: "splitBaseLM") {
            args.append("--split-base-lm")
        }
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
                    self.status = .error(
                        "Server exited unexpectedly (code \(proc.terminationStatus)).\nCheck logs for details."
                    )
                } else if self.status != .stopped {
                    self.status = .stopped
                }
            }
        }
        
        do {
            try process.run()
            log("🟢 Server process started (PID: \(process.processIdentifier))")
            DispatchQueue.main.async { [weak self] in self?.startHealthCheck() }
        } catch {
            log("❌ Failed to launch server: \(error)")
            DispatchQueue.main.async {
                self.status = .error("Failed to launch Python server:\n\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Graceful Shutdown (with force-kill fallback)
    
    /// Gracefully stops the server: SIGTERM → wait 5s → SIGINT → wait 3s → SIGKILL
    func stop() {
        log("🛑 Stopping server…")
        healthTimer?.invalidate()
        healthTimer = nil
        
        guard let process = process, process.isRunning else {
            status = .stopped
            return
        }
        
        let pid = process.processIdentifier
        log("📤 Sending SIGTERM to PID \(pid)…")
        process.terminate()  // SIGTERM
        
        // After 5 seconds, if still running, escalate to SIGINT (interrupt)
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self, let proc = self.process, proc.isRunning else { return }
            log("⏳ Process still alive, sending SIGINT (interrupt)…")
            proc.interrupt()  // SIGINT
            
            // After another 3 seconds, if still running, force-kill with SIGKILL
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, let proc = self.process, proc.isRunning else { return }
                let stubbornPid = proc.processIdentifier
                log("💀 Force-killing PID \(stubbornPid) with SIGKILL…")
                Darwin.kill(stubbornPid, SIGKILL)
            }
        }
        
        self.process = nil
        status = .stopped
        log("✅ Server stopped")
    }
    
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.start()
        }
    }
    
    // MARK: - Health Check
    
    private func startHealthCheck() {
        let startTime = Date()
        healthTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if Date().timeIntervalSince(startTime) > self.healthCheckTimeout {
                timer.invalidate()
                DispatchQueue.main.async {
                    if case .starting = self.status {
                        self.status = .error("Server took too long to start. Check logs for errors.")
                    }
                }
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
                    if case .starting = self.status {
                        self.status = .running
                        self.healthTimer?.invalidate()
                        self.healthTimer = nil
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Output Monitoring
    
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
    
    // MARK: - Port Utilities
    
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
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)"
        print(line)
        DispatchQueue.main.async { [weak self] in
            self?.outputBuffer += line + "\n"
            self?.logOutput = String(self?.outputBuffer.suffix(10000) ?? "")
        }
    }
    
    // MARK: - Convenience
    
    func openInBrowser() {
        if let url = URL(string: "http://127.0.0.1:\(port)") { NSWorkspace.shared.open(url) }
    }
    
    func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logOutput, forType: .string)
    }
}
