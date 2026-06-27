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
    
    /// uv package manager — either system-installed or bootstrapped by us.
    private var uvPath: String {
        return ServerManager.findUv() ?? "\(NSHomeDirectory())/.local/bin/uv"
    }
    
    /// voxcpmane2-server binary installed by `uv tool install`.
    private var serverBinary: String {
        return "\(NSHomeDirectory())/.local/bin/voxcpmane2-server"
    }
    
    /// Whether this Mac uses Apple Silicon (arm64).
    private var isAppleSilicon: Bool {
        var info = utsname()
        uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        return machine.hasPrefix("arm64") || machine.hasPrefix("aarch64")
    }
    
    // MARK: - Python Detection
    
    /// Find a system Python 3.10–3.12.
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
    
    // MARK: - uv Bootstrapping
    
    /// Locate `uv` on the system.
    private static func findUv() -> String? {
        let candidates = [
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            "\(NSHomeDirectory())/.local/bin/uv",
            "\(NSHomeDirectory())/.cargo/bin/uv",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // Fallback: ask the shell
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "command -v uv"]
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = FileHandle.nullDevice
        do {
            try task.run(); task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let found = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let f = found, !f.isEmpty, FileManager.default.fileExists(atPath: f) {
                return f
            }
        } catch {}
        return nil
    }
    
    /// Install `uv` via the official curl|sh script.
    private func installUv() -> Bool {
        log("📦 Installing uv package manager (astral.sh)…")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"]
        task.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(NSHomeDirectory())/.local/bin"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = pipe
        do {
            try task.run(); task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            log(output)
            if task.terminationStatus == 0 {
                let uvBin = "\(NSHomeDirectory())/.local/bin/uv"
                if FileManager.default.fileExists(atPath: uvBin) {
                    log("✅ uv installed at \(uvBin)")
                    return true
                }
            }
            log("❌ uv install script exited with code \(task.terminationStatus)")
            return false
        } catch {
            log("❌ Failed to install uv: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - voxcpmane2 Installation (via uv)
    
    /// Install or upgrade voxcpmane2 via `uv tool install`.
    /// - On Apple Silicon: installs 0.1.3b1 (required for --split-base-lm).
    /// - On Intel: installs latest stable.
    /// - Returns: true on success.
    func installVoxcpmane2(systemPython: String) -> Bool {
        // Ensure uv is available
        var uv = ServerManager.findUv()
        if uv == nil {
            guard installUv() else { return false }
            uv = ServerManager.findUv()
        }
        guard let uv = uv else {
            log("❌ uv not found after installation attempt")
            return false
        }
        
        // Build install arguments
        var args = ["tool", "install", "--python", systemPython]
        
        if isAppleSilicon {
            log("🍎 Apple Silicon detected — installing beta 0.1.3b1 for --split-base-lm support")
            args.append(contentsOf: ["--prerelease", "allow", "-U", "voxcpmane2==0.1.3b1"])
        } else {
            args.append(contentsOf: ["-U", "voxcpmane2"])
        }
        
        log("📦 Running: uv \(args.joined(separator: " "))")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: uv)
        task.arguments = args
        task.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(NSHomeDirectory())/.local/bin",
            "HOME": NSHomeDirectory()
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = pipe
        
        do {
            try task.run(); task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            log(output)
            
            if task.terminationStatus == 0 {
                // Verify the binary exists
                if FileManager.default.fileExists(atPath: serverBinary) {
                    log("✅ voxcpmane2-server installed at \(serverBinary)")
                    return true
                } else {
                    log("⚠️ uv tool install succeeded but \(serverBinary) not found")
                    // Try to locate it
                    let found = findUvToolBinary("voxcpmane2-server")
                    if found != nil {
                        log("✅ Found voxcpmane2-server at \(found!)")
                        return true
                    }
                    log("❌ Cannot locate voxcpmane2-server after installation")
                    return false
                }
            } else {
                log("❌ uv tool install exited with code \(task.terminationStatus)")
                return false
            }
        } catch {
            log("❌ uv tool install failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Find a binary installed by `uv tool install`.
    private func findUvToolBinary(_ name: String) -> String? {
        // uv tools are typically installed to ~/.local/bin
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/\(name)",
            "\(NSHomeDirectory())/.cargo/bin/\(name)",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // Search common uv tool directories
        let uvToolDirs = [
            "\(NSHomeDirectory())/.local/share/uv/tools",
        ]
        for dir in uvToolDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents {
                let binPath = "\(dir)/\(item)/bin/\(name)"
                if FileManager.default.fileExists(atPath: binPath) { return binPath }
            }
        }
        return nil
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
            
            // 2. Install/upgrade voxcpmane2 via uv tool install
            guard self.installVoxcpmane2(systemPython: systemPython) else {
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
            self.launchServer(port: port)
        }
    }
    
    private func launchServer(port: Int) {
        // Ensure the server binary exists
        var binary = serverBinary
        if !FileManager.default.fileExists(atPath: binary) {
            if let found = findUvToolBinary("voxcpmane2-server") {
                binary = found
            } else {
                log("❌ voxcpmane2-server not found")
                DispatchQueue.main.async { self.status = .error("voxcpmane2-server not found") }
                return
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        var args = ["--host", "127.0.0.1", "--port", "\(port)"]
        
        if let modelDir = UserDefaults.standard.string(forKey: "modelDirectory"), !modelDir.isEmpty {
            args.append(contentsOf: ["--model-dir", modelDir])
        }
        
        // --split-base-lm is only available in voxcpmane2 0.1.3b1 (pre-release)
        if UserDefaults.standard.bool(forKey: "splitBaseLM") {
            if isAppleSilicon {
                args.append("--split-base-lm")
                log("⚡ --split-base-lm enabled (Apple Silicon)")
            } else {
                log("⚠️ --split-base-lm is only supported on Apple Silicon, skipping")
            }
        }
        
        process.arguments = args
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(NSHomeDirectory())/.local/bin",
            "HOME": NSHomeDirectory()
        ]
        
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
                self.status = .error("Failed to launch server:\n\(error.localizedDescription)")
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
