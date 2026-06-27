import SwiftUI
import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case chinese = "zh"
    case english = "en"

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var effectiveLanguage: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh") {
                return "zh"
            }
            return "en"
        case .chinese: return "zh"
        case .english: return "en"
        }
    }
}

// MARK: - Localization Manager

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "VoxBox.appLanguage")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "VoxBox.appLanguage"),
           let lang = AppLanguage(rawValue: saved) {
            self.language = lang
        } else {
            self.language = .system
        }
    }

    var isChinese: Bool {
        language.effectiveLanguage == "zh"
    }
}

// MARK: - Localized Strings

/// All user-facing strings. Reads language from LocalizationManager.shared.
/// Views MUST observe LocalizationManager to re-render on language change.
@MainActor
struct L10n {
    private static var zh: Bool { LocalizationManager.shared.isChinese }

    // MARK: - General
    static var settings: String { zh ? "设置" : "Settings" }
    static var done: String { zh ? "完成" : "Done" }
    static var cancel: String { zh ? "取消" : "Cancel" }
    static var ok: String { zh ? "确定" : "OK" }
    static var retry: String { zh ? "重试" : "Retry" }
    static var home: String { zh ? "主页" : "Home" }
    static var quit: String { zh ? "退出 VoxBox" : "Quit VoxBox" }
    static var about: String { zh ? "关于" : "About" }
    static var version: String { "Version" }
    static var voxBox: String { "VoxBox" }

    // MARK: - Server Status
    static var statusRunning: String { zh ? "运行中" : "Running" }
    static var statusStarting: String { zh ? "启动中…" : "Starting…" }
    static var statusWarmingUp: String { zh ? "预热中…" : "Warming up…" }
    static var statusDownloading: String { zh ? "下载中" : "Downloading" }
    static var statusStopped: String { zh ? "已停止" : "Stopped" }
    static var statusError: String { zh ? "错误" : "Error" }
    static func downloadingPct(_ p: Int) -> String { zh ? "下载中 \(p)%" : "Downloading \(p)%" }

    // MARK: - Server Actions
    static var startServer: String { zh ? "启动服务器" : "Start Server" }
    static var stopServer: String { zh ? "停止服务器" : "Stop Server" }
    static var restartServer: String { zh ? "重启服务器" : "Restart Server" }
    static var openVoxBox: String { zh ? "打开 VoxBox" : "Open VoxBox" }
    static var stopAction: String { zh ? "停止" : "Stop" }
    static var cancelDownload: String { zh ? "取消下载" : "Cancel Download" }

    // MARK: - Audio
    static var saveAudio: String { zh ? "保存音频" : "Save Audio" }
    static var saveLastAudio: String { zh ? "💾 保存最近的音频…" : "💾 Save Last Audio…" }
    static var downloadHistory: String { zh ? "📥 下载历史" : "📥 Download History" }
    static var noAudioHistory: String { zh ? "暂无音频" : "No audio yet" }
    static var audioSaved: String { zh ? "音频已保存" : "Audio saved" }
    static var saveFailed: String { zh ? "保存失败" : "Save Failed" }
    static var noAudioToSave: String { zh ? "没有可保存的音频" : "No Audio to Save" }
    static var generateAudioFirst: String {
        zh ? "请先在网页界面生成语音，然后再保存。" : "Generate audio in the web UI first, then try saving again."
    }

    // MARK: - Launch
    static var startVoxBox: String { zh ? "启动 VoxBox" : "Start VoxBox" }
    static var voxBoxSubtitle: String {
        zh ? "基于 Apple Neural Engine 的文字转语音与声音克隆" : "Text-to-Speech & Voice Cloning on Apple Neural Engine"
    }
    static var firstLaunchNote: String {
        zh ? "首次启动将下载约 3.2GB 的 CoreML 模型。" : "On first launch, ~3.2GB of CoreML models will be downloaded."
    }
    static var requiresNote: String {
        zh ? "需要 Python 3.10–3.12 和 Apple Silicon Mac。" : "Requires Python 3.10–3.12 and Apple Silicon Mac."
    }

    // MARK: - Features
    static var featureTTS: String { zh ? "文字转语音" : "Text to Speech" }
    static var featureTTSDesc: String { zh ? "输入文字，自然朗读" : "Type any text and hear it spoken naturally" }
    static var featureClone: String { zh ? "声音克隆" : "Voice Cloning" }
    static var featureCloneDesc: String { zh ? "从 3 秒音频样本克隆任意声音" : "Clone any voice from a 3-second audio sample" }
    static var featureANE: String { zh ? "神经网络引擎" : "Neural Engine" }
    static var featureANEDesc: String { zh ? "完全在 Apple Silicon 上离线运行" : "Runs entirely on Apple Silicon, fully offline" }

    // MARK: - Loading
    static var loadingPython: String { zh ? "正在启动 Python 后端…" : "Starting Python backend…" }
    static var firstLaunchMoment: String { zh ? "首次启动可能需要一些时间…" : "This may take a moment on first launch…" }

    // MARK: - Warming Up
    static func serverWarmingUp(_ dots: Int) -> String {
        let d = String(repeating: ".", count: dots)
        return zh ? "服务器预热中\(d)" : "Server is warming up\(d)"
    }
    static var loadingCoreML: String { zh ? "正在将 CoreML 模型加载到神经网络引擎…" : "Loading CoreML models into Neural Engine…" }

    // MARK: - Download
    static var downloadingModels: String { zh ? "正在下载模型" : "Downloading Models" }
    static var downloadSubtitle: String {
        zh ? "首次启动 — 正在从 HuggingFace 下载 CoreML 模型" : "First launch — downloading CoreML models from HuggingFace"
    }
    static var oneTimeDownload: String {
        zh ? "这是一次性下载，模型将被缓存以供后续使用。" : "This is a one-time download. Models will be cached for future launches."
    }

    // MARK: - Error
    static var somethingWrong: String { zh ? "出了点问题" : "Something went wrong" }
    static var details: String { zh ? "详情" : "Details" }
    static var hide: String { zh ? "隐藏" : "Hide" }
    static var copyLogs: String { zh ? "复制日志" : "Copy Logs" }
    static var reportIssue: String { zh ? "报告问题" : "Report Issue" }
    static var installPython: String { zh ? "安装 Python: brew install python@3.12" : "Install Python: brew install python@3.12" }
    static var goBackHome: String { zh ? "回到主页" : "Go back to the home screen" }
    static var tryAgain: String { zh ? "重试启动" : "Try starting the server again" }
    static var showHideDetails: String { zh ? "显示/隐藏详细错误信息" : "Show or hide detailed error information" }

    // MARK: - Settings
    static var settingsServer: String { zh ? "服务器" : "Server" }
    static var settingsPerformance: String { zh ? "性能" : "Performance" }
    static var settingsGeneral: String { zh ? "通用" : "General" }
    static var settingsLogs: String { zh ? "日志" : "Logs" }
    static var settingsLanguage: String { zh ? "语言" : "Language" }
    static var autoStartServer: String { zh ? "启动时自动运行服务器" : "Auto-start server on launch" }
    static var autoStartDesc: String { zh ? "打开 VoxBox 时自动启动服务器" : "Server will start automatically when VoxBox opens" }
    static var serverPort: String { zh ? "服务器端口" : "Server port" }
    static var defaultPort: String { zh ? "默认: 8650" : "Default: 8650" }
    static var modelDirectory: String { zh ? "模型目录" : "Model directory" }
    static var defaultModelPath: String { zh ? "默认: ~/Library/Application Support/VoxBox/models" : "Default: ~/Library/Application Support/VoxBox/models" }
    static var browse: String { zh ? "浏览…" : "Browse…" }
    static var splitBaseLM: String { zh ? "拆分基础语言模型" : "Split Base LM" }
    static var splitBaseLMDesc: String { zh ? "减少内存占用 (~2GB)。推荐 8GB Mac 使用。" : "Reduces memory usage (~2GB less). Recommended for 8GB Macs." }
    static var launchAtLogin: String { zh ? "登录时启动" : "Launch at login" }
    static var showServerLogs: String { zh ? "显示服务器日志" : "Show Server Logs" }
    static var noLogs: String { zh ? "暂无日志…" : "No logs yet…" }
    static var selectModelDir: String { zh ? "选择模型目录" : "Select Model Directory" }

    // MARK: - Language Settings
    static var languageLabel: String { zh ? "界面语言" : "Interface Language" }
    static var languageDesc: String { zh ? "选择 VoxBox 的显示语言" : "Choose the display language for VoxBox" }

    // MARK: - Save Panel
    static var saveGeneratedAudio: String { zh ? "保存生成的音频" : "Save Generated Audio" }
    static var mp3NotAvailable: String { zh ? "MP3 编码器不可用" : "MP3 Encoder Not Available" }
    static var mp3NotAvailableDesc: String {
        zh ? "MP3 编码需要 ffmpeg 或 lame。\n\n安装 ffmpeg: brew install ffmpeg\n然后重启 VoxBox。\n\n是否改为保存 WAV？"
           : "MP3 encoding requires ffmpeg or lame.\n\nInstall ffmpeg: brew install ffmpeg\nThen restart VoxBox.\n\nSave as WAV instead?"
    }
    static var saveAsWav: String { zh ? "保存为 WAV" : "Save as WAV" }
    static var tryWavInstead: String { zh ? "尝试 WAV 格式" : "Try WAV Instead" }

    // MARK: - Menu Bar
    static var status: String { zh ? "状态" : "Status" }
    static var port: String { zh ? "端口" : "Port" }

    // MARK: - Auto-save & Recordings Folder
    static var autoSavedTitle: String { zh ? "🎵 已自动保存" : "🎵 Auto-saved" }
    static var autoSavedToFolder: String {
        zh ? "已保存至 VoxBox Recordings 文件夹" : "Saved to VoxBox Recordings folder"
    }
    static var openRecordingsFolder: String { zh ? "📂 打开文件夹" : "📂 Open Folder" }
    static var saveAsButton: String { zh ? "💾 另存为…" : "💾 Save As…" }
    static var openRecordingsFolderMenu: String {
        zh ? "📂 打开录音文件夹" : "📂 Open Recordings Folder"
    }

    // MARK: - JS Injected Strings (used in WebView JS)
    static var jsSave: String { zh ? "💾 保存" : "💾 Save" }
    static var jsSaved: String { zh ? "✅ 已保存!" : "✅ Saved!" }
    static var jsNoAudio: String { zh ? "暂无音频" : "No audio yet" }
    static var jsDownloadHistory: String { zh ? "📥 历史" : "📥 History" }
    static var jsClose: String { zh ? "✕" : "✕" }
    static var jsClockTooltip: String {
        zh ? "打开录音文件夹" : "Open Recordings Folder"
    }
    static var jsAutoSavedToast: String {
        zh ? "🎵 已自动保存" : "🎵 Auto-saved"
    }
    static var jsOpenFolder: String { zh ? "📂" : "📂" }
    static var jsSaveAs: String { zh ? "💾" : "💾" }
}
