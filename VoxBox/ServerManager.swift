//
//  ServerManager.swift
//  VoxBox
//
//  Manages the voxcpmane2 Python server lifecycle.
//  Uses `uv` for package management to avoid PEP 668 restrictions.
//
//  Chip-specific behavior:
//    M1 / M1 Pro / M1 Max / M1 Ultra
//      → Installs voxcpmane2==0.1.3b1 (beta) with --split-base-lm.
//        Reason: M1 ANE cannot load the full BaseLM package;
//        --split-base-lm downloads two smaller split packages instead.
//    M2 / M3 / M4 and later
//      → Installs latest stable voxcpmane2 (no --split-base-lm).
//
//  Safety net for all chips:
//    If stderr contains "ANE model load has failed" at runtime,
//    the server stops and suggests switching to the beta version.
//

import Foundation
import AppKit

// MARK: - Log Entry

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

// MARK: - Server Manager

@MainActor
final class ServerManager: ObservableObject {

    // MARK: - Server Status (nested)

    enum ServerStatus: Equatable {
        case stopped
        case starting
        case downloading(progress: Double)
        case warmingUp(port: Int)   // Process launched, waiting for HTTP to respond
        case running(port: Int)
        case error(String)
    }

    @Published var status: ServerStatus = .stopped
    @Published var logs: [LogEntry] = []

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var healthCheckTask: Task<Void, Never>?

    private let appSupportDir: URL
    private let uvPath: String
    private let isM1Series: Bool
    private let isAppleSilicon: Bool

    // MARK: - Init

    init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("VoxBox")

        self.appSupportDir = base
        self.uvPath = ServerManager.findUv()
        self.isAppleSilicon = ServerManager.isAppleSiliconMac()
        self.isM1Series = ServerManager.isM1Series()

        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        if isM1Series {
            appendLog("🍎 M1-series chip detected — will use beta + --split-base-lm")
        } else if isAppleSilicon {
            appendLog("🍎 Apple Silicon (M2+) detected — using stable release")
        } else {
            appendLog("🖥 Intel Mac detected")
        }
    }

    // MARK: - Computed properties

    /// Returns the current server port, or 0 if not running / warming up.
    var port: Int {
        switch status {
        case .running(let port), .warmingUp(let port):
            return port
        default:
            return 0
        }
    }

    /// Full server log as a single string (for display / clipboard).
    var logOutput: String {
        logs.map { "[\($0.timestamp.formatted())] \($0.message)" }.joined(separator: "\n")
    }

    // MARK: - Public API

    func start() {
        guard case .stopped = status else { return }
        status = .starting
        logs.removeAll()
        healthCheckTask?.cancel()

        Task.detached(priority: .userInitiated) {
            await self.performStart()
        }
    }

    func stop() {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            // Give it 2 seconds to shut down gracefully, then force-kill
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if proc.isRunning {
                    proc.terminate()
                }
            }
        }
        process = nil
        status = .stopped
        appendLog("⏹ Server stopped.")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.start()
        }
    }

    func openInBrowser() {
        let p = port
        guard p > 0 else { return }
        if let url = URL(string: "http://127.0.0.1:\(p)") {
            NSWorkspace.shared.open(url)
        }
    }

    func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logOutput, forType: .string)
        appendLog("📋 Logs copied to clipboard")
    }

    // MARK: - Start Sequence

    private func performStart() async {
        // ── 1. Locate or install `uv` ──
        let uv: String
        if !uvPath.isEmpty {
            uv = uvPath
            appendLog("✅ Found uv at \(uv)")
        } else {
            appendLog("📦 Installing uv package manager…")
            do {
                uv = try await installUv()
                appendLog("✅ uv installed at \(uv)")
            } catch {
                setError("Failed to install uv: \(error.localizedDescription)")
                return
            }
        }

        // ── 2. Find system Python (3.10–3.12) ──
        guard let pythonPath = ServerManager.findSystemPython() else {
            setError("Python >=3.10,<3.13 not found. Install via Homebrew: brew install python@3.12")
            return
        }
        appendLog("✅ Found \(pythonPath)")

        // ── 3. Install voxcpmane2 ──
        //    M1 series → beta with --split-base-lm
        //    M2+       → latest stable
        let installArgs: [String]
        if isM1Series {
            appendLog("🍎 M1-series: installing voxcpmane2==0.1.3b1 for --split-base-lm")
            installArgs = [
                "tool", "install",
                "--python", pythonPath,
                "--prerelease", "allow",
                "-U",
                "voxcpmane2==0.1.3b1",
            ]
        } else {
            installArgs = [
                "tool", "install",
                "--python", pythonPath,
                "-U",
                "voxcpmane2",
            ]
        }

        do {
            appendLog("📦 Running: uv \(installArgs.joined(separator: " "))")
            let output = try await runAsync(uv, args: installArgs)
            appendLog(output)
        } catch {
            setError("uv tool install failed: \(error.localizedDescription)")
            return
        }

        // ── 4. Locate voxcpmane2-server ──
        let serverBinary = "\(NSHomeDirectory())/.local/bin/voxcpmane2-server"
        guard FileManager.default.fileExists(atPath: serverBinary) else {
            setError("voxcpmane2-server not found at \(serverBinary)")
            return
        }
        appendLog("✅ voxcpmane2-server: \(serverBinary)")

        // ── 5. Find available port ──
        guard let port = findAvailablePort() else {
            setError("No available port found.")
            return
        }
        appendLog("🔌 Using port \(port)")

        // ── 6. Build launch arguments ──
        var serverArgs = [
            "--host", "127.0.0.1",
            "--port", "\(port)",
        ]
        if isM1Series {
            serverArgs.append("--split-base-lm")
            appendLog("⚡ Launching with --split-base-lm (M1-series)")
        }

        // ── 7. Launch server ──
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: serverBinary)
        proc.arguments = serverArgs
        proc.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(NSHomeDirectory())/.local/bin",
            "HOME": NSHomeDirectory(),
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        // Stderr accumulator for ANE error safety net
        let stderrAccumulator = StderrAccumulator { [weak self] fullStderr in
            Task { @MainActor in
                self?.handleANEError(stderr: fullStderr)
            }
        }

        self.process = proc
        self.stdoutPipe = outPipe
        self.stderrPipe = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                Task { @MainActor in self.appendLog(text) }
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                Task { @MainActor in
                    self.appendLog("[stderr] \(text)")
                    stderrAccumulator.append(text)
                }
            }
        }

        do {
            try proc.run()
            appendLog("🟢 Server process started (PID: \(proc.processIdentifier))")

            // ⚠️ Don't set .running yet — poll until the server actually responds
            status = .warmingUp(port: port)
            appendLog("⏳ Waiting for server to become ready...")

            // Start health-check polling in background
            healthCheckTask = Task.detached { [weak self] in
                await self?.waitForServerReady(port: port, timeoutSeconds: 60)
            }

            // Monitor process exit
            Task.detached {
                proc.waitUntilExit()
                let exitCode = proc.terminationStatus
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.healthCheckTask?.cancel()
                    self.healthCheckTask = nil
                    switch self.status {
                    case .running, .warmingUp:
                        self.appendLog("⚠ Server exited with code \(exitCode)")
                        if exitCode != 0 {
                            self.status = .error("Server exited unexpectedly (code \(exitCode))")
                        }
                    default:
                        break
                    }
                }
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Health Check Polling

    /// Polls http://127.0.0.1:<port> until it responds (200 OK) or timeout.
    private func waitForServerReady(port: Int, timeoutSeconds: Int) async {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        let url = URL(string: "http://127.0.0.1:\(port)/")!

        while Date() < deadline {
            // Check if task was cancelled
            if Task.isCancelled { return }

            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
                request.httpMethod = "HEAD"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    // Any HTTP response (even 404) means the server is listening
                    if httpResponse.statusCode > 0 {
                        await MainActor.run { [weak self] in
                            guard let self = self else { return }
                            // Only transition if we're still warming up
                            if case .warmingUp = self.status {
                                self.status = .running(port: port)
                                self.appendLog("✅ Server is ready (HTTP \(httpResponse.statusCode))")
                            }
                        }
                        return
                    }
                }
            } catch {
                // Connection refused or timeout — server not ready yet
                // Just retry after a short delay
            }

            // Wait 1.5 seconds before next attempt
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        // Timeout
        await MainActor.run { [weak self] in
            guard let self = self else { return }
            if case .warmingUp = self.status {
                self.status = .error("Server did not respond within \(timeoutSeconds)s. Check logs for details.")
                self.appendLog("❌ Health check timed out after \(timeoutSeconds)s")
            }
        }
    }

    // MARK: - ANE Error Safety Net

    /// If an ANE compilation error is detected in stderr at runtime,
    /// stop the server and suggest the beta workaround.
    private func handleANEError(stderr: String) {
        let anePatterns = [
            "ANE model load has failed",
            "re-compile the E5 bundle",
            "ANE compilation error",
            "on-device compiled macho",
        ]

        guard anePatterns.contains(where: { stderr.contains($0) }) else { return }

        appendLog("⚠️ ANE compilation error detected!")

        healthCheckTask?.cancel()
        healthCheckTask = nil

        // Stop the process
        if let proc = process, proc.isRunning {
            proc.terminate()
            Thread.sleep(forTimeInterval: 1)
            if proc.isRunning {
                proc.terminate()
            }
        }
        process = nil

        let message = """
        ANE model load has failed for on-device compiled macho.
        Must re-compile the E5 bundle.

        This is a known issue with the full BaseLM package on some Apple Silicon Macs.
        The workaround is to use the beta version with --split-base-lm:

          uv tool uninstall voxcpmane2
          uv tool install --python '>=3.10,<3.13' --prerelease allow -U voxcpmane2==0.1.3b1
          voxcpmane2-server --split-base-lm --host 127.0.0.1 --port XXXX

        See: https://github.com/0seba/VoxCPMANE#m1-baselm-load-workaround
        """

        status = .error(message)
        appendLog(message)
    }

    // MARK: - Chip Detection

    /// All Apple Silicon (M1, M2, M3, M4, ...) report "arm64" from uname.
    private static func isAppleSiliconMac() -> Bool {
        var info = utsname()
        uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        return machine.hasPrefix("arm64") || machine.hasPrefix("aarch64")
    }

    /// Returns true for M1, M1 Pro, M1 Max, M1 Ultra.
    /// Uses sysctl machdep.cpu.brand_string (e.g. "Apple M1 Pro").
    private static func isM1Series() -> Bool {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return false }
        var chars = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &chars, &size, nil, 0)
        let brand = String(cString: chars)
        // Matches "Apple M1", "Apple M1 Pro", "Apple M1 Max", "Apple M1 Ultra"
        return brand.hasPrefix("Apple M1")
    }

    // MARK: - Install uv

    private static func findUv() -> String {
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
        let which = try? runSync("/bin/sh", args: ["-c", "command -v uv"])
        if let p = which?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            return p
        }
        return ""
    }

    private func installUv() async throws -> String {
        let scriptURL = "https://astral.sh/uv/install.sh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "curl -LsSf \(scriptURL) | sh"]
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(NSHomeDirectory())/.local/bin"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        appendLog(output)

        guard process.terminationStatus == 0 else {
            throw ServerError.uvInstallFailed(output)
        }

        let uvPath = "\(NSHomeDirectory())/.local/bin/uv"
        guard FileManager.default.fileExists(atPath: uvPath) else {
            throw ServerError.uvNotFoundAfterInstall
        }
        return uvPath
    }

    // MARK: - Helpers

    private static func findSystemPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3.12",
            "/usr/local/bin/python3.12",
            "/opt/homebrew/bin/python3.11",
            "/usr/local/bin/python3.11",
            "/opt/homebrew/bin/python3.10",
            "/usr/local/bin/python3.10",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        let which = try? runSync("/bin/sh", args: ["-c", "command -v python3"])
        if let p = which?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            let ver = (try? runSync(p, args: ["--version"])) ?? ""
            if ver.contains("3.10") || ver.contains("3.11") || ver.contains("3.12") {
                return p
            }
        }
        return nil
    }

    private func findAvailablePort() -> Int? {
        for port in 1024...65535 {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else { continue }
            defer { close(sock) }

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(port).bigEndian
            addr.sin_addr.s_addr = in_addr_t(bigEndian: 0x7f000001)

            let addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(sock, $0, addrLen)
                }
            }
            if result == 0 {
                return port
            }
        }
        return nil
    }

    // MARK: - Status updates

    private func setRunning(port: Int) {
        status = .running(port: port)
    }

    private func setError(_ message: String) {
        status = .error(message)
    }

    private func appendLog(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        logs.append(LogEntry(timestamp: Date(), message: trimmed))
        print("[VoxBox] \(trimmed)")
    }
}

// MARK: - Stderr Accumulator

private final class StderrAccumulator {
    private var buffer = ""
    private let callback: (String) -> Void
    private var fired = false

    private let triggerPatterns = [
        "ANE model load has failed",
        "re-compile the E5 bundle",
    ]

    init(callback: @escaping (String) -> Void) {
        self.callback = callback
    }

    func append(_ text: String) {
        guard !fired else { return }
        buffer += text
        for pattern in triggerPatterns {
            if buffer.contains(pattern) {
                fired = true
                callback(buffer)
                return
            }
        }
    }
}

// MARK: - Shell helpers

private func runSync(_ executable: String, args: [String]) throws -> String {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = args
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    try proc.run()
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

private func runAsync(_ executable: String, args: [String]) async throws -> String {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: executable)
    proc.arguments = args
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    try proc.run()
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    if proc.terminationStatus != 0 {
        throw ServerError.commandFailed(output)
    }
    return output
}

// MARK: - Errors

enum ServerError: LocalizedError {
    case uvInstallFailed(String)
    case uvNotFoundAfterInstall
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .uvInstallFailed(let msg):
            return "Failed to install uv: \(msg)"
        case .uvNotFoundAfterInstall:
            return "uv was installed but not found at expected path"
        case .commandFailed(let msg):
            return "Command failed: \(msg)"
        }
    }
}
