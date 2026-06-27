//
//  ServerManager.swift
//  VoxBox
//
//  Manages the voxcpmane2 Python server lifecycle.
//  Uses `uv` for package management to avoid PEP 668 restrictions.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import Darwin

// MARK: - Audio Format

enum AudioFormat: String, CaseIterable {
    case wav = "WAV"
    case mp3 = "MP3"

    var fileExtension: String { rawValue.lowercased() }
    var mimeType: String {
        switch self {
        case .wav: return "audio/wav"
        case .mp3: return "audio/mpeg"
        }
    }

    var utType: UTType {
        switch self {
        case .wav: return .wav
        case .mp3: return .mp3
        }
    }
}

// MARK: - Audio Clip (for download history)

struct AudioClip: Identifiable {
    let id = UUID()
    let data: Data
    let text: String
    let timestamp: Date
}

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
        case warmingUp(port: Int)
        case running(port: Int)
        case error(String)
    }

    @Published var status: ServerStatus = .stopped
    @Published var logs: [LogEntry] = []

    /// Last captured audio data (kept for backward compat).
    @Published var lastAudioData: Data?
    /// The text that was used to generate the last audio.
    @Published var lastAudioText: String?

    /// Full history of captured audio clips (max 50).
    @Published var audioHistory: [AudioClip] = []

    /// Preferred export format.
    @Published var preferredFormat: AudioFormat {
        didSet {
            UserDefaults.standard.set(preferredFormat.rawValue, forKey: "VoxBox.preferredFormat")
        }
    }

    /// Whether MP3 export is available (requires ffmpeg, lame, or working afconvert).
    @Published var mp3Available: Bool = false

    /// Custom output folder path (stored in UserDefaults). If empty, uses default.
    @Published var outputFolderPath: String {
        didSet {
            UserDefaults.standard.set(outputFolderPath, forKey: "VoxBox.outputFolderPath")
            try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        }
    }

    /// Resolved output folder URL.
    var outputFolder: URL {
        if !outputFolderPath.isEmpty,
           let url = URL(string: "file://" + outputFolderPath),
           FileManager.default.fileExists(atPath: outputFolderPath) {
            return url
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("VoxBox Output")
    }

    /// Legacy alias for backward compat.
    var recordingsFolder: URL { outputFolder }

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var healthCheckTask: Task<Void, Never>?

    private let appSupportDir: URL
    private let cachedUvPath: String
    private let isM1Series: Bool
    private let isAppleSilicon: Bool

    /// Path to a working MP3 encoder (ffmpeg or lame), if any.
    private var mp3EncoderPath: String?

    /// Max number of audio clips to keep in history.
    private let maxHistoryCount = 50

    // MARK: - Init

    init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("VoxBox")

        self.appSupportDir = base
        self.cachedUvPath = ServerManager.findUv()
        self.isAppleSilicon = ServerManager.isAppleSiliconMac()
        self.isM1Series = ServerManager.isM1Series()

        // Restore output folder path from UserDefaults
        if let saved = UserDefaults.standard.string(forKey: "VoxBox.outputFolderPath"),
           !saved.isEmpty,
           FileManager.default.fileExists(atPath: saved) {
            self.outputFolderPath = saved
        } else {
            self.outputFolderPath = ""
        }

        // Restore saved format preference
        if let saved = UserDefaults.standard.string(forKey: "VoxBox.preferredFormat"),
           let fmt = AudioFormat(rawValue: saved) {
            self.preferredFormat = fmt
        } else {
            self.preferredFormat = .wav
        }

        // Ensure output folder exists
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )

        // Detect MP3 encoder availability
        self.mp3EncoderPath = ServerManager.detectMP3Encoder()
        self.mp3Available = mp3EncoderPath != nil

        if isM1Series {
            appendLog("🍎 M1-series chip detected — will use beta + --split-base-lm")
        } else if isAppleSilicon {
            appendLog("🍎 Apple Silicon (M2+) detected — using stable release")
        } else {
            appendLog("🖥 Intel Mac detected")
        }

        if mp3Available, let path = mp3EncoderPath {
            appendLog("🎵 MP3 encoder found: \(path)")
        } else {
            appendLog("⚠️ No MP3 encoder found (install ffmpeg: brew install ffmpeg)")
        }
    }

    // MARK: - Computed properties

    var port: Int {
        switch status {
        case .running(let port), .warmingUp(let port):
            return port
        default:
            return 0
        }
    }

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if proc.isRunning {
                    proc.terminate()
                }
            }
        }
        process = nil
        status = .stopped
        lastAudioData = nil
        lastAudioText = nil
        audioHistory.removeAll()
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

    // MARK: - Audio Capture

    func captureAudio(data: Data, text: String) {
        lastAudioData = data
        lastAudioText = text

        let clip = AudioClip(data: data, text: text, timestamp: Date())
        audioHistory.append(clip)

        while audioHistory.count > maxHistoryCount {
            audioHistory.removeFirst()
        }

        autoSave(audioData: data, text: text)

        appendLog("🎵 Audio captured: \(data.count) bytes, text: \"\(text.prefix(40))\" (history: \(audioHistory.count))")
    }

    // MARK: - Output Folder

    func openRecordingsFolder() {
        NSWorkspace.shared.open(outputFolder)
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.chooseFolder
        panel.message = L10n.outputFolderDesc
        if panel.runModal() == .OK, let url = panel.url {
            outputFolderPath = url.path
            appendLog("📂 Output folder changed to: \(url.path)")
        }
    }

    func resetOutputFolder() {
        outputFolderPath = ""
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        appendLog("📂 Output folder reset to default: \(outputFolder.path)")
    }

    // MARK: - Auto-save

    private func autoSave(audioData: Data, text: String) {
        let folder = outputFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let fmt = preferredFormat

        var name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            name = name
                .replacingOccurrences(of: ":", with: "：")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if name.count > 60 { name = String(name.prefix(60)) }
        }
        if name.isEmpty { name = "recording" }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = df.string(from: Date())
        let filename = "\(timestamp)_\(name).\(fmt.fileExtension)"
        let fileURL = folder.appendingPathComponent(filename)

        let outputData: Data
        if fmt == .mp3 && mp3Available {
            do {
                outputData = try convertToMP3(wavData: audioData)
            } catch {
                appendLog("⚠️ MP3 conversion failed for auto-save, using WAV: \(error.localizedDescription)")
                outputData = audioData
            }
        } else {
            outputData = audioData
        }

        do {
            try outputData.write(to: fileURL)
            appendLog("💾 Auto-saved: \(filename)")
        } catch {
            appendLog("⚠️ Auto-save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Audio (Manual)

    private func filenameFromText(_ text: String?, format: AudioFormat) -> String {
        var name = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !name.isEmpty {
            name = name
                .replacingOccurrences(of: ":", with: "：")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if name.count > 100 {
                name = String(name.prefix(100))
            }
        }

        if name.isEmpty {
            name = "voxbox_output"
        }

        return "\(name).\(format.fileExtension)"
    }

    func saveAudio(format: AudioFormat? = nil) {
        saveAudio(historyIndex: nil, format: format)
    }

    func saveAudio(historyIndex: Int?, format: AudioFormat? = nil) {
        let fmt = format ?? preferredFormat

        let clip: AudioClip?
        if let idx = historyIndex, idx >= 0, idx < audioHistory.count {
            clip = audioHistory[idx]
        } else {
            clip = audioHistory.last
        }

        guard let clip = clip else {
            appendLog("⚠️ No audio data to save.")
            let alert = NSAlert()
            alert.messageText = L10n.noAudioToSave
            alert.informativeText = L10n.generateAudioFirst
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.ok)
            alert.runModal()
            return
        }

        let effectiveFormat: AudioFormat
        if fmt == .mp3 && !mp3Available {
            effectiveFormat = .wav
            appendLog("⚠️ MP3 encoder not available — saving as WAV instead.")
        } else {
            effectiveFormat = fmt
        }

        let savePanel = NSSavePanel()
        savePanel.title = L10n.saveGeneratedAudio
        savePanel.nameFieldStringValue = filenameFromText(clip.text, format: effectiveFormat)

        if mp3Available {
            savePanel.allowedContentTypes = [effectiveFormat.utType,
                                              effectiveFormat == .wav ? .mp3 : .wav]
        } else {
            savePanel.allowedContentTypes = [.wav]
        }
        savePanel.canCreateDirectories = true
        savePanel.allowsOtherFileTypes = false

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url, let self = self else { return }

            Task { @MainActor in
                let chosenExt = url.pathExtension.lowercased()
                let chosenFormat: AudioFormat = chosenExt == "mp3" ? .mp3 : .wav

                if chosenFormat == .mp3 && !self.mp3Available {
                    let alert = NSAlert()
                    alert.messageText = L10n.mp3NotAvailable
                    alert.informativeText = L10n.mp3NotAvailableDesc
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L10n.saveAsWav)
                    alert.addButton(withTitle: L10n.cancel)
                    if alert.runModal() == .alertFirstButtonReturn {
                        self.saveAudio(historyIndex: historyIndex, format: .wav)
                    }
                    return
                }

                do {
                    let outputData: Data
                    switch chosenFormat {
                    case .wav:
                        outputData = clip.data
                    case .mp3:
                        outputData = try self.convertToMP3(wavData: clip.data)
                    }

                    try outputData.write(to: url)
                    self.appendLog("💾 Audio saved to \(url.path) (\(chosenFormat.rawValue))")
                } catch {
                    self.appendLog("❌ Failed to save audio: \(error.localizedDescription)")

                    let alert = NSAlert()
                    alert.messageText = L10n.saveFailed
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: L10n.ok)

                    if case .mp3 = chosenFormat {
                        alert.addButton(withTitle: L10n.tryWavInstead)
                        let result = alert.runModal()
                        if result == .alertSecondButtonReturn {
                            self.saveAudio(historyIndex: historyIndex, format: .wav)
                        }
                    } else {
                        alert.runModal()
                    }
                }
            }
        }
    }

    // MARK: - MP3 Conversion

    private func convertToMP3(wavData: Data) throws -> Data {
        if let encoderPath = mp3EncoderPath {
            if encoderPath.hasSuffix("ffmpeg") {
                return try convertWithFFmpeg(wavData: wavData)
            } else if encoderPath.hasSuffix("lame") {
                return try convertWithLame(wavData: wavData)
            }
        }
        return try convertWithAfconvert(wavData: wavData)
    }

    private func convertWithFFmpeg(wavData: Data) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let wavURL = tempDir.appendingPathComponent("voxbox_\(UUID().uuidString).wav")
        let mp3URL = tempDir.appendingPathComponent("voxbox_\(UUID().uuidString).mp3")

        try wavData.write(to: wavURL)
        defer {
            try? FileManager.default.removeItem(at: wavURL)
            try? FileManager.default.removeItem(at: mp3URL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mp3EncoderPath ?? "/usr/local/bin/ffmpeg")
        process.arguments = [
            "-y", "-i", wavURL.path,
            "-codec:a", "libmp3lame", "-b:a", "192k", "-q:a", "2",
            mp3URL.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "VoxBox.ffmpeg",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "ffmpeg MP3 conversion failed: \(errorStr)"]
            )
        }

        return try Data(contentsOf: mp3URL)
    }

    private func convertWithLame(wavData: Data) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let wavURL = tempDir.appendingPathComponent("voxbox_\(UUID().uuidString).wav")
        let mp3URL = tempDir.appendingPathComponent("voxbox_\(UUID().uuidString).mp3")

        try wavData.write(to: wavURL)
        defer {
            try? FileManager.default.removeItem(at: wavURL)
            try? FileManager.default.removeItem(at: mp3URL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mp3EncoderPath ?? "/usr/local/bin/lame")
        process.arguments = ["-h", "-b", "192", wavURL.path, mp3URL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "VoxBox.lame",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "lame MP3 conversion failed: \(errorStr)"]
            )
        }

        return try Data(contentsOf: mp3URL)
    }

    private func convertWithAfconvert(wavData: Data) throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let wavURL = tempDir.appendingPathComponent("voxbox_\(UUID().uuidString).wav")
        let mp3URL = tempDir.appendingPathComponent("voxbox_\(UUID().uuidString).mp3")

        try wavData.write(to: wavURL)
        defer {
            try? FileManager.default.removeItem(at: wavURL)
            try? FileManager.default.removeItem(at: mp3URL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = ["-f", "mp3f", "-d", "mp3", wavURL.path, "-o", mp3URL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0,
           FileManager.default.fileExists(atPath: mp3URL.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: mp3URL.path),
           let fileSize = attrs[.size] as? Int,
           fileSize > 0 {
            return try Data(contentsOf: mp3URL)
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        throw NSError(
            domain: "VoxBox.afconvert",
            code: Int(process.terminationStatus),
            userInfo: [
                NSLocalizedDescriptionKey: """
                MP3 conversion failed.

                macOS's afconvert does not include an MP3 encoder.
                Please install ffmpeg: brew install ffmpeg
                Then restart VoxBox.

                Technical details: \(errorStr)
                """
            ]
        )
    }

    // MARK: - MP3 Encoder Detection

    private static func detectMP3Encoder() -> String? {
        let ffmpegPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "\(NSHomeDirectory())/.local/bin/ffmpeg",
        ]
        for path in ffmpegPaths {
            if FileManager.default.fileExists(atPath: path) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: path)
                proc.arguments = ["-version"]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 { return path }
                } catch {}
            }
        }

        let lamePaths = [
            "/opt/homebrew/bin/lame",
            "/usr/local/bin/lame",
        ]
        for path in lamePaths {
            if FileManager.default.fileExists(atPath: path) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: path)
                proc.arguments = ["--version"]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    if proc.terminationStatus == 0 { return path }
                } catch {}
            }
        }

        return nil
    }

    // MARK: - Start Sequence (redesigned)

    /// Single entry point for the server startup sequence.
    /// Flow: ensure uv → find Python → install voxcpmane2 → find port → launch server → health check.
    private func performStart() async {
        // ── Step 1: Ensure uv is available and executable ──
        let uv: String
        do {
            uv = try await ensureUv()
        } catch {
            setError("Failed to setup uv: \(error.localizedDescription)")
            return
        }
        appendLog("✅ uv ready: \(uv)")

        // ── Step 2: Find Python 3.10–3.12 ──
        guard let pythonPath = ServerManager.findSystemPython() else {
            setError("Python >=3.10,<3.13 not found. Install via Homebrew: brew install python@3.12")
            return
        }
        appendLog("✅ Found \(pythonPath)")

        // ── Step 3: Install voxcpmane2 via uv tool install ──
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
            appendLog("📦 Running: \(uv) \(installArgs.joined(separator: " "))")
            let output = try await runAsync(uv, args: installArgs)
            appendLog(output)
        } catch {
            // If uv binary disappeared (sandbox quirk), try reinstalling once
            let nsErr = error as NSError
            if nsErr.domain == "NSCocoaErrorDomain" && nsErr.code == 4 {
                appendLog("⚠️ uv binary disappeared — attempting reinstall…")
                do {
                    let freshUv = try await installUv()
                    appendLog("✅ Reinstalled uv at: \(freshUv)")
                    let output = try await runAsync(freshUv, args: installArgs)
                    appendLog(output)
                } catch {
                    setError("uv tool install failed (after reinstall): \(error.localizedDescription)")
                    return
                }
            } else {
                setError("uv tool install failed: \(error.localizedDescription)")
                return
            }
        }

        // ── Step 4: Verify voxcpmane2-server binary ──
        let serverBinary = "\(NSHomeDirectory())/.local/bin/voxcpmane2-server"
        guard FileManager.default.fileExists(atPath: serverBinary) else {
            setError("voxcpmane2-server not found at \(serverBinary)")
            return
        }
        appendLog("✅ voxcpmane2-server: \(serverBinary)")

        // ── Step 5: Find available port ──
        guard let port = findAvailablePort() else {
            setError("No available port found.")
            return
        }
        appendLog("🔌 Using port \(port)")

        // ── Step 6: Launch server process ──
        var serverArgs = [
            "--host", "127.0.0.1",
            "--port", "\(port)",
        ]
        if isM1Series {
            serverArgs.append("--split-base-lm")
            appendLog("⚡ Launching with --split-base-lm (M1-series)")
        }

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

            status = .warmingUp(port: port)
            appendLog("⏳ Waiting for server to become ready...")

            healthCheckTask = Task.detached { [weak self] in
                await self?.waitForServerReady(port: port, timeoutSeconds: 60)
            }

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

    // MARK: - UV Management (redesigned — single source of truth)

    /// Returns a guaranteed-executable uv path.
    /// Tries cached path → system search → fresh install.
    private func ensureUv() async throws -> String {
        // 1. Check cached path (must be executable, not just exist)
        if !cachedUvPath.isEmpty,
           FileManager.default.isExecutableFile(atPath: cachedUvPath) {
            return cachedUvPath
        }

        // 2. Search system with executable check + auto chmod
        if let found = ServerManager.findUvExecutable() {
            return found
        }

        // 3. Install fresh (includes chmod +x and retry)
        appendLog("📦 Installing uv package manager…")
        return try await installUv()
    }

    /// Use POSIX chmod to set +x on a file (works inside sandbox).
    /// Marked nonisolated so it can be called from background queues.
    private static nonisolated func chmodX(_ path: String) -> Bool {
        let result = Darwin.chmod(path, 0o755)
        return result == 0
    }

    /// Search for an executable uv binary.
    /// If a candidate exists but lacks +x, attempt chmod +x before giving up.
    /// Marked nonisolated so it can be called from background queues.
    private static nonisolated func findUvExecutable() -> String? {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/uv",
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            "\(NSHomeDirectory())/.cargo/bin/uv",
        ]

        for path in candidates {
            // Fast path: already executable
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
            // File exists but not executable → try POSIX chmod +x
            if FileManager.default.fileExists(atPath: path) {
                if chmodX(path),
                   FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        // Fallback: use `which uv`
        if let result = try? runSync("/bin/sh", args: ["-c", "command -v uv 2>/dev/null"]) {
            let p = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p.isEmpty, p.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }

        return nil
    }

    /// Legacy findUv — used in init() to cache a path early.
    /// Now also tries chmod +x on existing-but-not-executable files.
    private static func findUv() -> String {
        if let found = findUvExecutable() {
            return found
        }
        // Fallback: return path even if not (yet) executable — it may become executable later
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/uv",
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            "\(NSHomeDirectory())/.cargo/bin/uv",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return ""
    }

    /// Download and install uv via the official install script.
    /// Runs on a background thread; uses POSIX chmod +x after install; retries up to 6 times.
    private func installUv() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ServerError.uvInstallFailed("self deallocated"))
                    return
                }

                do {
                    let scriptURL = "https://astral.sh/uv/install.sh"
                    let install = Process()
                    install.executableURL = URL(fileURLWithPath: "/bin/bash")
                    install.arguments = ["-c", "curl -LsSf \(scriptURL) | sh"]

                    // Inherit environment; ensure common bin dirs are in PATH
                    var env = ProcessInfo.processInfo.environment
                    var path = env["PATH"] ?? "/usr/bin:/bin"
                    for add in [
                        "\(NSHomeDirectory())/.local/bin",
                        "/opt/homebrew/bin",
                        "\(NSHomeDirectory())/.cargo/bin",
                    ] {
                        if !path.contains(add) {
                            path = "\(add):\(path)"
                        }
                    }
                    env["PATH"] = path
                    install.environment = env

                    let pipe = Pipe()
                    install.standardOutput = pipe
                    install.standardError = pipe

                    try install.run()
                    install.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    Task { @MainActor in self.appendLog(output) }

                    guard install.terminationStatus == 0 else {
                        continuation.resume(throwing: ServerError.uvInstallFailed(output))
                        return
                    }

                    // ── Parse install directory from output ──
                    // uv install script prints: "installing to <path>"
                    var installDir = "\(NSHomeDirectory())/.local/bin"
                    for line in output.components(separatedBy: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("installing to") {
                            let parts = trimmed.components(separatedBy: "installing to")
                            if parts.count > 1 {
                                let dir = parts[1].trimmingCharacters(in: .whitespaces)
                                if !dir.isEmpty { installDir = dir }
                            }
                        }
                    }

                    // ── POSIX chmod +x the installed binaries ──
                    // CRITICAL: uv install script does NOT set +x.
                    // Using Darwin.chmod() syscall because Process + /bin/chmod
                    // is silently denied inside App Sandbox.
                    let uvBinaryPath = "\(installDir)/uv"
                    let uvxBinaryPath = "\(installDir)/uvx"

                    var chmodOk = true
                    for binaryPath in [uvBinaryPath, uvxBinaryPath] {
                        if FileManager.default.fileExists(atPath: binaryPath) {
                            if !ServerManager.chmodX(binaryPath) {
                                chmodOk = false
                                Task { @MainActor in
                                    self.appendLog("⚠️ chmod +x failed (errno=\(errno)) for \(binaryPath)")
                                }
                            }
                        }
                    }
                    if chmodOk {
                        Task { @MainActor in self.appendLog("🔧 chmod +x applied to uv binaries") }
                    }

                    // ── Retry loop: wait for file + execute permission ──
                    for i in 1...6 {
                        if FileManager.default.isExecutableFile(atPath: uvBinaryPath) {
                            continuation.resume(returning: uvBinaryPath)
                            return
                        }

                        // Debug: list directory with permission flags
                        var dirLog = "📂 Contents of \(installDir):"
                        if let files = try? FileManager.default.contentsOfDirectory(atPath: installDir) {
                            for f in files.sorted() {
                                let fp = "\(installDir)/\(f)"
                                var flags = ""
                                if FileManager.default.isReadableFile(atPath: fp) { flags += "r" }
                                if FileManager.default.isWritableFile(atPath: fp) { flags += "w" }
                                if FileManager.default.isExecutableFile(atPath: fp) { flags += "x" }
                                dirLog += "\n[\(flags)] \(f)"
                            }
                        } else {
                            dirLog += "\n(no files or directory not readable)"
                        }
                        let capturedDirLog = dirLog
                        Task { @MainActor in self.appendLog(capturedDirLog) }

                        if i < 6 {
                            Task { @MainActor in self.appendLog("⏳ uv not executable yet, retrying (\(i)/6)…") }
                            Thread.sleep(forTimeInterval: 1.0)
                        }
                    }

                    // ── Final attempt: re-run findUvExecutable ──
                    if let found = ServerManager.findUvExecutable() {
                        continuation.resume(returning: found)
                        return
                    }

                    continuation.resume(throwing: ServerError.uvNotFoundAfterInstall)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Health Check Polling

    private func waitForServerReady(port: Int, timeoutSeconds: Int) async {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        let url = URL(string: "http://127.0.0.1:\(port)/")!

        while Date() < deadline {
            if Task.isCancelled { return }

            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3)
                request.httpMethod = "HEAD"
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode > 0 {
                        await MainActor.run { [weak self] in
                            guard let self = self else { return }
                            if case .warmingUp = self.status {
                                self.status = .running(port: port)
                                self.appendLog("✅ Server is ready (HTTP \(httpResponse.statusCode))")
                            }
                        }
                        return
                    }
                }
            } catch {
                // Connection refused — retry
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        await MainActor.run { [weak self] in
            guard let self = self else { return }
            if case .warmingUp = self.status {
                self.status = .error("Server did not respond within \(timeoutSeconds)s. Check logs for details.")
                self.appendLog("❌ Health check timed out after \(timeoutSeconds)s")
            }
        }
    }

    // MARK: - ANE Error Safety Net

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

    private static func isM1Series() -> Bool {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return false }
        var chars = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &chars, &size, nil, 0)
        let brand = String(cString: chars)
        return brand.hasPrefix("Apple M1")
    }

    // MARK: - Python Detection

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

    // MARK: - Port Management (optimized)

    /// Find an available port, trying common ports first.
    private func findAvailablePort() -> Int? {
        // Fast path: try preferred ports first (covers >95% of cases)
        let preferred = [8765, 8888, 8890, 8900, 8766, 5000, 3000, 8080, 9090, 9000]
        for port in preferred {
            if isPortAvailable(port) { return port }
        }
        // Slow path: scan the range
        for port in 1024...65535 {
            if isPortAvailable(port) { return port }
        }
        return nil
    }

    /// Check if a specific port is available for binding on 127.0.0.1.
    private func isPortAvailable(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
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
        return result == 0
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
