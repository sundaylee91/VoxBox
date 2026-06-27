import SwiftUI
import WebKit

// MARK: - VoxBox Local Frontend HTML

enum VoxBoxHTML {
    /// Returns the full HTML document with the server port injected.
    static func html(port: Int) -> String {
        return template.replacingOccurrences(of: "{{PORT}}", with: "\(port)")
    }

    // MARK: - Template

    private static let template: String = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>VoxBox</title>
<style>
    :root {
        --bg-start: #f0f0f5;
        --bg-end: #e5e5ee;
        --card-bg: #ffffff;
        --card-border: rgba(0,0,0,0.06);
        --card-shadow: 0 2px 16px rgba(0,0,0,0.06), 0 0 0 1px rgba(0,0,0,0.04);
        --text-primary: #1d1d1f;
        --text-secondary: #6e6e73;
        --text-tertiary: #aeaeb2;
        --input-bg: #f5f5f7;
        --input-border: rgba(0,0,0,0.08);
        --input-focus-border: #007AFF;
        --input-focus-shadow: 0 0 0 3px rgba(0,122,255,0.15);
        --btn-primary-bg: linear-gradient(135deg, #007AFF 0%, #5856D6 100%);
        --btn-primary-text: #ffffff;
        --btn-primary-shadow: 0 2px 10px rgba(0,122,255,0.3);
        --btn-secondary-bg: transparent;
        --btn-secondary-border: rgba(0,0,0,0.12);
        --btn-secondary-text: #1d1d1f;
        --btn-secondary-hover-bg: rgba(0,0,0,0.04);
        --divider: rgba(0,0,0,0.06);
        --status-success: #30D158;
        --status-error: #FF453A;
        --status-info: #007AFF;
        --slider-track: rgba(0,0,0,0.12);
        --slider-fill: #007AFF;
        --wave-color: #007AFF;
        --char-count-normal: #aeaeb2;
        --char-count-warn: #FF9F0A;
        --char-count-over: #FF453A;
        --toast-bg: rgba(30,30,46,0.92);
        --toast-text: #e2e8f0;
        --player-bg: #f8f8fa;
        --player-progress-track: rgba(0,0,0,0.1);
    }

    @media (prefers-color-scheme: dark) {
        :root {
            --bg-start: #1c1c1e;
            --bg-end: #161618;
            --card-bg: #2c2c2e;
            --card-border: rgba(255,255,255,0.08);
            --card-shadow: 0 2px 16px rgba(0,0,0,0.2), 0 0 0 1px rgba(255,255,255,0.05);
            --text-primary: #f5f5f7;
            --text-secondary: #98989d;
            --text-tertiary: #636366;
            --input-bg: #1c1c1e;
            --input-border: rgba(255,255,255,0.08);
            --input-focus-border: #0A84FF;
            --input-focus-shadow: 0 0 0 3px rgba(10,132,255,0.2);
            --btn-primary-bg: linear-gradient(135deg, #0A84FF 0%, #5E5CE6 100%);
            --btn-primary-text: #ffffff;
            --btn-primary-shadow: 0 2px 10px rgba(10,132,255,0.35);
            --btn-secondary-border: rgba(255,255,255,0.12);
            --btn-secondary-text: #f5f5f7;
            --btn-secondary-hover-bg: rgba(255,255,255,0.06);
            --divider: rgba(255,255,255,0.06);
            --slider-track: rgba(255,255,255,0.12);
            --slider-fill: #0A84FF;
            --wave-color: #0A84FF;
            --char-count-normal: #636366;
            --toast-bg: rgba(44,44,46,0.95);
            --toast-text: #e5e5ea;
            --player-bg: #2c2c2e;
            --player-progress-track: rgba(255,255,255,0.1);
        }
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
        font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'SF Pro Display', system-ui, sans-serif;
        background: linear-gradient(180deg, var(--bg-start) 0%, var(--bg-end) 100%);
        color: var(--text-primary);
        min-height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        user-select: none;
        -webkit-user-select: none;
    }

    .container {
        width: 100%;
        max-width: 600px;
        padding: 40px 24px;
    }

    /* ── Header ── */
    .header {
        text-align: center;
        margin-bottom: 32px;
    }

    .logo {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        margin-bottom: 16px;
    }

    /* Animated waveform bars */
    .waveform {
        display: flex;
        align-items: flex-end;
        gap: 2px;
        height: 32px;
    }

    .waveform .bar {
        width: 3px;
        background: var(--wave-color);
        border-radius: 2px;
        animation: wave 1.2s ease-in-out infinite;
    }

    .waveform .bar:nth-child(1) { height: 12px; animation-delay: 0s; }
    .waveform .bar:nth-child(2) { height: 24px; animation-delay: 0.1s; }
    .waveform .bar:nth-child(3) { height: 16px; animation-delay: 0.2s; }
    .waveform .bar:nth-child(4) { height: 28px; animation-delay: 0.3s; }
    .waveform .bar:nth-child(5) { height: 20px; animation-delay: 0.4s; }
    .waveform .bar:nth-child(6) { height: 14px; animation-delay: 0.5s; }
    .waveform .bar:nth-child(7) { height: 22px; animation-delay: 0.6s; }

    @keyframes wave {
        0%, 100% { transform: scaleY(1); opacity: 0.6; }
        50% { transform: scaleY(1.8); opacity: 1; }
    }

    .header h1 {
        font-size: 28px;
        font-weight: 700;
        letter-spacing: -0.4px;
        color: var(--text-primary);
        margin-bottom: 4px;
    }

    .header .subtitle {
        font-size: 14px;
        font-weight: 400;
        color: var(--text-secondary);
        letter-spacing: -0.1px;
    }

    /* ── Card ── */
    .card {
        background: var(--card-bg);
        border: 1px solid var(--card-border);
        border-radius: 20px;
        box-shadow: var(--card-shadow);
        padding: 24px;
        display: flex;
        flex-direction: column;
        gap: 18px;
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
    }

    /* ── Textarea ── */
    .input-wrapper {
        position: relative;
        display: flex;
        flex-direction: column;
    }

    textarea {
        width: 100%;
        min-height: 120px;
        padding: 14px 16px;
        font-family: inherit;
        font-size: 15px;
        font-weight: 400;
        line-height: 1.5;
        color: var(--text-primary);
        background: var(--input-bg);
        border: 1.5px solid var(--input-border);
        border-radius: 14px;
        resize: vertical;
        outline: none;
        transition: border-color 0.2s ease, box-shadow 0.2s ease;
        -webkit-appearance: none;
    }

    textarea:focus {
        border-color: var(--input-focus-border);
        box-shadow: var(--input-focus-shadow);
    }

    textarea::placeholder {
        color: var(--text-tertiary);
        font-weight: 400;
    }

    .input-footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-top: 6px;
        padding: 0 4px;
    }

    .char-count {
        font-size: 11px;
        font-weight: 500;
        color: var(--char-count-normal);
        transition: color 0.2s ease;
        letter-spacing: -0.1px;
    }

    .char-count.warn { color: var(--char-count-warn); }
    .char-count.over { color: var(--char-count-over); }

    .clear-btn {
        font-size: 11px;
        font-weight: 500;
        color: var(--text-tertiary);
        background: none;
        border: none;
        cursor: pointer;
        opacity: 0;
        transition: opacity 0.2s ease, color 0.15s ease;
        pointer-events: none;
        letter-spacing: -0.1px;
    }

    .clear-btn.visible {
        opacity: 1;
        pointer-events: auto;
    }

    .clear-btn:hover {
        color: var(--text-secondary);
    }

    /* ── Voice Preset Section ── */
    .voice-section {
        display: flex;
        flex-direction: column;
        gap: 10px;
    }

    .voice-row {
        display: flex;
        gap: 8px;
        align-items: center;
    }

    .voice-select {
        flex: 1;
        padding: 8px 12px;
        font-family: inherit;
        font-size: 13px;
        font-weight: 500;
        color: var(--text-primary);
        background: var(--input-bg);
        border: 1.5px solid var(--input-border);
        border-radius: 10px;
        outline: none;
        cursor: pointer;
        transition: border-color 0.2s ease;
        -webkit-appearance: none;
        appearance: none;
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6'%3E%3Cpath d='M0 0l5 6 5-6z' fill='%2398989d'/%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: right 12px center;
        padding-right: 30px;
    }

    .voice-select:focus {
        border-color: var(--input-focus-border);
    }

    .voice-mode-select {
        width: 130px;
        padding: 8px 10px;
        font-family: inherit;
        font-size: 12px;
        font-weight: 500;
        color: var(--text-secondary);
        background: var(--input-bg);
        border: 1.5px solid var(--input-border);
        border-radius: 10px;
        outline: none;
        cursor: pointer;
        transition: border-color 0.2s ease;
        -webkit-appearance: none;
        appearance: none;
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6'%3E%3Cpath d='M0 0l5 6 5-6z' fill='%2398989d'/%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: right 8px center;
        padding-right: 24px;
    }

    .voice-refresh {
        background: none;
        border: none;
        cursor: pointer;
        font-size: 14px;
        color: var(--text-tertiary);
        padding: 2px 6px;
        border-radius: 6px;
        transition: all 0.15s ease;
    }

    .voice-refresh:hover {
        color: var(--text-primary);
        background: var(--btn-secondary-hover-bg);
    }

    /* ── Advanced Settings Toggle ── */
    .advanced-toggle {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 12px;
        font-weight: 500;
        color: var(--text-tertiary);
        cursor: pointer;
        background: none;
        border: none;
        padding: 2px 0;
        transition: color 0.15s ease;
        letter-spacing: -0.1px;
    }

    .advanced-toggle:hover { color: var(--text-secondary); }

    .advanced-toggle .chevron {
        display: inline-block;
        font-size: 10px;
        transition: transform 0.25s ease;
    }

    .advanced-toggle.open .chevron {
        transform: rotate(180deg);
    }

    /* ── Advanced Panel ── */
    .advanced-panel {
        overflow: hidden;
        max-height: 0;
        opacity: 0;
        transition: max-height 0.35s ease, opacity 0.25s ease, margin 0.25s ease;
        display: flex;
        flex-direction: column;
        gap: 14px;
    }

    .advanced-panel.open {
        max-height: 300px;
        opacity: 1;
        margin-top: 2px;
    }

    .setting-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
    }

    .setting-label {
        font-size: 13px;
        font-weight: 500;
        color: var(--text-secondary);
        white-space: nowrap;
        letter-spacing: -0.1px;
    }

    .setting-value {
        font-size: 12px;
        font-weight: 600;
        color: var(--text-primary);
        min-width: 38px;
        text-align: right;
    }

    /* ── Slider ── */
    input[type="range"] {
        -webkit-appearance: none;
        appearance: none;
        width: 140px;
        height: 6px;
        border-radius: 3px;
        background: var(--slider-track);
        outline: none;
        cursor: pointer;
    }

    input[type="range"]::-webkit-slider-thumb {
        -webkit-appearance: none;
        width: 20px;
        height: 20px;
        border-radius: 50%;
        background: #ffffff;
        border: 2px solid var(--slider-fill);
        box-shadow: 0 1px 6px rgba(0,0,0,0.12);
        cursor: pointer;
        transition: box-shadow 0.15s ease;
    }

    input[type="range"]::-webkit-slider-thumb:active {
        box-shadow: 0 0 0 6px rgba(0,122,255,0.18);
    }

    /* ── Buttons ── */
    .btn-row {
        display: flex;
        gap: 10px;
    }

    .btn {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        padding: 11px 20px;
        font-family: inherit;
        font-size: 14px;
        font-weight: 600;
        letter-spacing: -0.2px;
        border-radius: 12px;
        cursor: pointer;
        transition: all 0.2s ease;
        white-space: nowrap;
        -webkit-appearance: none;
    }

    .btn:disabled {
        opacity: 0.4;
        cursor: not-allowed;
        pointer-events: none;
    }

    .btn-primary {
        background: var(--btn-primary-bg);
        color: var(--btn-primary-text);
        border: none;
        box-shadow: var(--btn-primary-shadow);
        position: relative;
        overflow: hidden;
    }

    .btn-primary::after {
        content: '';
        position: absolute;
        inset: 0;
        background: linear-gradient(180deg, rgba(255,255,255,0.15) 0%, transparent 60%);
        border-radius: 12px;
        pointer-events: none;
    }

    .btn-primary:hover:not(:disabled) {
        transform: translateY(-1px);
        box-shadow: 0 4px 18px rgba(0,122,255,0.4);
    }

    .btn-primary:active:not(:disabled) {
        transform: translateY(0);
        box-shadow: 0 1px 6px rgba(0,122,255,0.3);
    }

    .btn-secondary {
        background: var(--btn-secondary-bg);
        color: var(--btn-secondary-text);
        border: 1.5px solid var(--btn-secondary-border);
    }

    .btn-secondary:hover:not(:disabled) {
        background: var(--btn-secondary-hover-bg);
        border-color: rgba(0,122,255,0.3);
    }

    .btn-secondary:active:not(:disabled) {
        background: rgba(0,122,255,0.08);
    }

    /* ── Status message ── */
    .status {
        text-align: center;
        font-size: 12px;
        font-weight: 500;
        min-height: 20px;
        line-height: 20px;
        transition: color 0.3s ease;
        letter-spacing: -0.1px;
    }

    .status.idle { color: var(--text-tertiary); }
    .status.generating { color: var(--status-info); }
    .status.success { color: var(--status-success); }
    .status.error { color: var(--status-error); }

    /* ── Spinner (inline) ── */
    @keyframes spin {
        to { transform: rotate(360deg); }
    }

    .spinner {
        display: inline-block;
        width: 16px;
        height: 16px;
        border: 2px solid rgba(255,255,255,0.3);
        border-top-color: #ffffff;
        border-radius: 50%;
        animation: spin 0.7s linear infinite;
        vertical-align: middle;
    }

    /* ── Toast ── */
    @keyframes toastIn {
        from { transform: translateX(-50%) translateY(-12px); opacity: 0; }
        to { transform: translateX(-50%) translateY(0); opacity: 1; }
    }
    @keyframes toastOut {
        from { transform: translateX(-50%) translateY(0); opacity: 1; }
        to { transform: translateX(-50%) translateY(-12px); opacity: 0; }
    }

    .toast {
        position: fixed;
        top: 16px;
        left: 50%;
        transform: translateX(-50%);
        z-index: 9999;
        padding: 8px 16px;
        background: var(--toast-bg);
        color: var(--toast-text);
        font-size: 12px;
        font-weight: 500;
        border-radius: 10px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.25);
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        pointer-events: none;
        animation: toastIn 0.25s ease-out forwards;
        letter-spacing: -0.1px;
    }

    .toast.out {
        animation: toastOut 0.2s ease-in forwards;
    }

    /* ── Audio Player ── */
    .player-card {
        margin-top: 16px;
        background: var(--card-bg);
        border: 1px solid var(--card-border);
        border-radius: 16px;
        box-shadow: var(--card-shadow);
        padding: 14px 18px;
        display: none;
        flex-direction: column;
        gap: 10px;
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
    }

    .player-card.visible {
        display: flex;
    }

    .player-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
    }

    .player-title {
        font-size: 12px;
        font-weight: 600;
        color: var(--text-secondary);
        letter-spacing: -0.1px;
    }

    .player-filename {
        font-size: 11px;
        font-weight: 400;
        color: var(--text-tertiary);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        max-width: 240px;
    }

    .player-body {
        display: flex;
        align-items: center;
        gap: 10px;
    }

    .player-btn {
        width: 34px;
        height: 34px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 16px;
        background: var(--input-bg);
        color: var(--text-primary);
        border: 1.5px solid var(--input-border);
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.15s ease;
        flex-shrink: 0;
    }

    .player-btn:hover {
        background: var(--btn-secondary-hover-bg);
        border-color: rgba(0,122,255,0.3);
    }

    .player-btn:active {
        background: rgba(0,122,255,0.08);
    }

    .player-btn.play-btn {
        width: 40px;
        height: 40px;
        font-size: 18px;
        background: var(--btn-primary-bg);
        color: var(--btn-primary-text);
        border: none;
        box-shadow: var(--btn-primary-shadow);
    }

    .player-btn.play-btn:hover {
        transform: scale(1.05);
        box-shadow: 0 4px 18px rgba(0,122,255,0.4);
    }

    .player-progress-container {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 3px;
        min-width: 0;
    }

    .player-progress {
        -webkit-appearance: none;
        appearance: none;
        width: 100%;
        height: 5px;
        border-radius: 3px;
        background: var(--player-progress-track);
        outline: none;
        cursor: pointer;
    }

    .player-progress::-webkit-slider-thumb {
        -webkit-appearance: none;
        width: 14px;
        height: 14px;
        border-radius: 50%;
        background: var(--slider-fill);
        border: 2px solid #ffffff;
        box-shadow: 0 1px 4px rgba(0,0,0,0.15);
        cursor: pointer;
    }

    .player-times {
        display: flex;
        justify-content: space-between;
        font-size: 10px;
        font-weight: 500;
        color: var(--text-tertiary);
        letter-spacing: 0;
    }

    /* ── Hidden audio element (kept for playback) ── */
    #audio-player { display: none; }

    /* ── Scrollbar ── */
    ::-webkit-scrollbar {
        width: 6px;
    }

    ::-webkit-scrollbar-track {
        background: transparent;
    }

    ::-webkit-scrollbar-thumb {
        background: var(--text-tertiary);
        border-radius: 3px;
        opacity: 0.5;
    }

    ::-webkit-scrollbar-thumb:hover {
        background: var(--text-secondary);
    }

    /* ── Focus ring for accessibility ── */
    :focus-visible {
        outline: 2px solid var(--input-focus-border);
        outline-offset: 2px;
        border-radius: 6px;
    }
</style>
</head>
<body>
<div class="container">
    <!-- Header -->
    <div class="header">
        <div class="logo">
            <div class="waveform" id="waveform-icon">
                <div class="bar"></div>
                <div class="bar"></div>
                <div class="bar"></div>
                <div class="bar"></div>
                <div class="bar"></div>
                <div class="bar"></div>
                <div class="bar"></div>
            </div>
        </div>
        <h1>VoxBox</h1>
        <p class="subtitle">Native AI Text-to-Speech on Apple Neural Engine</p>
    </div>

    <!-- Main Card -->
    <div class="card">
        <!-- Text Input -->
        <div class="input-wrapper">
            <textarea
                id="text-input"
                placeholder="Type or paste text to speak…"
                maxlength="2000"
                rows="4"
            ></textarea>
            <div class="input-footer">
                <span class="char-count" id="char-count">0 / 2000</span>
                <button class="clear-btn" id="clear-btn" title="Clear text">Clear</button>
            </div>
        </div>

        <!-- Voice Preset -->
        <div class="voice-section">
            <div class="setting-row">
                <span class="setting-label">🎤 Voice</span>
                <button class="voice-refresh" id="voice-refresh" title="Refresh voices">↻</button>
            </div>
            <div class="voice-row">
                <select id="voice-select" class="voice-select">
                    <option value="">Loading voices…</option>
                </select>
                <select id="voice-mode-select" class="voice-mode-select">
                    <option value="reference">Reference</option>
                    <option value="high_similarity">High Sim</option>
                </select>
            </div>
        </div>

        <!-- Advanced Settings Toggle -->
        <button class="advanced-toggle" id="advanced-toggle">
            <span>Advanced Settings</span>
            <span class="chevron">▾</span>
        </button>

        <!-- Advanced Panel -->
        <div class="advanced-panel" id="advanced-panel">
            <div class="setting-row">
                <span class="setting-label">Speed</span>
                <input type="range" id="speed-slider" min="0.5" max="2.0" step="0.1" value="1.0">
                <span class="setting-value" id="speed-value">1.0x</span>
            </div>
            <div class="setting-row">
                <span class="setting-label">Sample Rate</span>
                <input type="range" id="sample-rate-slider" min="16000" max="48000" step="1000" value="24000">
                <span class="setting-value" id="sample-rate-value">24 kHz</span>
            </div>
            <div class="setting-row">
                <span class="setting-label">CFG Scale</span>
                <input type="range" id="cfg-slider" min="1.0" max="4.0" step="0.1" value="2.0">
                <span class="setting-value" id="cfg-value">2.0</span>
            </div>
            <div class="setting-row">
                <span class="setting-label">Timesteps</span>
                <input type="range" id="timesteps-slider" min="4" max="30" step="1" value="10">
                <span class="setting-value" id="timesteps-value">10</span>
            </div>
        </div>

        <!-- Action Buttons -->
        <div class="btn-row">
            <button class="btn btn-primary" id="btn-generate-play" disabled>
                <span id="btn-icon-play">▶</span>
                <span id="btn-text-play">Generate &amp; Play</span>
            </button>
            <button class="btn btn-secondary" id="btn-generate-save" disabled>
                <span>↓</span>
                <span>Save Audio</span>
            </button>
        </div>

        <!-- Status -->
        <div class="status idle" id="status">Ready</div>
    </div>

    <!-- Audio Player -->
    <div class="player-card" id="player-card">
        <div class="player-header">
            <span class="player-title">🔊 Audio Player</span>
            <span class="player-filename" id="player-filename"></span>
        </div>
        <div class="player-body">
            <button class="player-btn play-btn" id="btn-play-pause" title="Play / Pause">▶</button>
            <div class="player-progress-container">
                <input type="range" class="player-progress" id="player-progress" min="0" max="100" value="0">
                <div class="player-times">
                    <span id="time-current">00:00</span>
                    <span id="time-duration">00:00</span>
                </div>
            </div>
            <button class="player-btn" id="btn-replay" title="Replay">↺</button>
            <button class="player-btn" id="btn-download-audio" title="Download">↓</button>
        </div>
    </div>
</div>

<!-- Hidden audio player -->
<audio id="audio-player"></audio>

<script>
(function() {
    'use strict';

    // ── Configuration ──
    var SERVER_PORT = {{PORT}};
    var API_BASE = 'http://127.0.0.1:' + SERVER_PORT;
    var SPEECH_ENDPOINT = API_BASE + '/v1/audio/speech';
    var VOICES_ENDPOINT = API_BASE + '/voices';

    // ── DOM refs ──
    var textInput = document.getElementById('text-input');
    var charCount = document.getElementById('char-count');
    var clearBtn = document.getElementById('clear-btn');
    var advancedToggle = document.getElementById('advanced-toggle');
    var advancedPanel = document.getElementById('advanced-panel');
    var speedSlider = document.getElementById('speed-slider');
    var speedValue = document.getElementById('speed-value');
    var sampleRateSlider = document.getElementById('sample-rate-slider');
    var sampleRateValue = document.getElementById('sample-rate-value');
    var cfgSlider = document.getElementById('cfg-slider');
    var cfgValue = document.getElementById('cfg-value');
    var timestepsSlider = document.getElementById('timesteps-slider');
    var timestepsValue = document.getElementById('timesteps-value');
    var voiceSelect = document.getElementById('voice-select');
    var voiceModeSelect = document.getElementById('voice-mode-select');
    var voiceRefresh = document.getElementById('voice-refresh');
    var btnGeneratePlay = document.getElementById('btn-generate-play');
    var btnGenerateSave = document.getElementById('btn-generate-save');
    var btnIconPlay = document.getElementById('btn-icon-play');
    var btnTextPlay = document.getElementById('btn-text-play');
    var statusEl = document.getElementById('status');
    var audioPlayer = document.getElementById('audio-player');
    var waveformIcon = document.getElementById('waveform-icon');

    // ── Player DOM refs ──
    var playerCard = document.getElementById('player-card');
    var playerFilename = document.getElementById('player-filename');
    var btnPlayPause = document.getElementById('btn-play-pause');
    var playerProgress = document.getElementById('player-progress');
    var timeCurrent = document.getElementById('time-current');
    var timeDuration = document.getElementById('time-duration');
    var btnReplay = document.getElementById('btn-replay');
    var btnDownloadAudio = document.getElementById('btn-download-audio');

    // ── State ──
    var isGenerating = false;
    var lastAudioBlob = null;
    var lastText = '';
    var availableVoices = [];
    var playerSeeking = false;

    // ── Format time ──
    function formatTime(seconds) {
        if (isNaN(seconds) || !isFinite(seconds)) return '00:00';
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }

    // ── Load available voices ──
    function loadVoices() {
        voiceSelect.innerHTML = '<option value="">Loading…</option>';
        voiceSelect.disabled = true;

        fetch(VOICES_ENDPOINT)
            .then(function(response) {
                if (!response.ok) throw new Error('HTTP ' + response.status);
                return response.json();
            })
            .then(function(data) {
                availableVoices = [];
                voiceSelect.innerHTML = '';

                // Add "none" option for default voice
                var defaultOpt = document.createElement('option');
                defaultOpt.value = '';
                defaultOpt.textContent = 'Default (no preset)';
                voiceSelect.appendChild(defaultOpt);

                if (data && data.voices && Array.isArray(data.voices)) {
                    data.voices.forEach(function(v) {
                        var name = typeof v === 'string' ? v : (v.name || v.voice_name || '');
                        if (name) {
                            availableVoices.push(name);
                            var opt = document.createElement('option');
                            opt.value = name;
                            opt.textContent = name;
                            voiceSelect.appendChild(opt);
                        }
                    });
                }

                if (availableVoices.length === 0) {
                    var noOpt = document.createElement('option');
                    noOpt.value = '';
                    noOpt.textContent = 'No preset voices found';
                    noOpt.disabled = true;
                    voiceSelect.appendChild(noOpt);
                }

                voiceSelect.disabled = false;
                console.log('[VoxBox] Loaded ' + availableVoices.length + ' voices');
            })
            .catch(function(err) {
                voiceSelect.innerHTML = '<option value="">Failed to load voices</option>';
                voiceSelect.disabled = false;
                console.warn('[VoxBox] Voice load error:', err);
            });
    }

    voiceRefresh.addEventListener('click', loadVoices);

    // ── Character count ──
    function updateCharCount() {
        var len = textInput.value.length;
        var max = 2000;
        charCount.textContent = len + ' / ' + max;
        charCount.classList.remove('warn', 'over');
        if (len > max * 0.85 && len <= max) charCount.classList.add('warn');
        if (len > max) charCount.classList.add('over');

        // Toggle clear button
        if (len > 0) {
            clearBtn.classList.add('visible');
        } else {
            clearBtn.classList.remove('visible');
        }

        // Enable/disable buttons
        var hasText = len > 0 && len <= max;
        btnGeneratePlay.disabled = !hasText || isGenerating;
        btnGenerateSave.disabled = !hasText || isGenerating;
    }

    textInput.addEventListener('input', updateCharCount);

    clearBtn.addEventListener('click', function() {
        textInput.value = '';
        updateCharCount();
        textInput.focus();
    });

    // ── Advanced settings toggle ──
    advancedToggle.addEventListener('click', function() {
        var isOpen = advancedPanel.classList.toggle('open');
        advancedToggle.classList.toggle('open', isOpen);
    });

    // ── Sliders ──
    speedSlider.addEventListener('input', function() {
        speedValue.textContent = parseFloat(speedSlider.value).toFixed(1) + 'x';
    });

    sampleRateSlider.addEventListener('input', function() {
        sampleRateValue.textContent = (parseInt(sampleRateSlider.value) / 1000).toFixed(0) + ' kHz';
    });

    cfgSlider.addEventListener('input', function() {
        cfgValue.textContent = parseFloat(cfgSlider.value).toFixed(1);
    });

    timestepsSlider.addEventListener('input', function() {
        timestepsValue.textContent = timestepsSlider.value;
    });

    // ── Helpers ──
    function setStatus(state, message) {
        statusEl.className = 'status ' + state;
        statusEl.textContent = message;
    }

    function setGenerating(generating) {
        isGenerating = generating;
        updateCharCount();

        if (generating) {
            btnIconPlay.innerHTML = '<span class="spinner"></span>';
            btnTextPlay.textContent = 'Generating…';
            waveformIcon.style.opacity = '0.5';
        } else {
            btnIconPlay.textContent = '▶';
            btnTextPlay.textContent = 'Generate & Play';
            waveformIcon.style.opacity = '1';
        }
    }

    function showToast(message) {
        var existing = document.querySelector('.toast');
        if (existing) existing.remove();

        var toast = document.createElement('div');
        toast.className = 'toast';
        toast.textContent = message;
        document.body.appendChild(toast);

        setTimeout(function() {
            toast.classList.add('out');
            setTimeout(function() {
                if (toast.parentNode) toast.parentNode.removeChild(toast);
            }, 250);
        }, 3000);
    }

    // ── Show audio player ──
    function showPlayer(text, blob) {
        playerFilename.textContent = text ? (text.length > 50 ? text.substring(0, 47) + '…' : text) : 'Generated Audio';
        playerCard.classList.add('visible');
        lastAudioBlob = blob;

        // Update duration when metadata loads
        var url = URL.createObjectURL(blob);
        audioPlayer.src = url;

        audioPlayer.onloadedmetadata = function() {
            var dur = audioPlayer.duration;
            timeDuration.textContent = formatTime(dur);
            playerProgress.max = Math.floor(dur * 100) || 100;
        };

        audioPlayer.onended = function() {
            btnPlayPause.textContent = '▶';
            playerProgress.value = 0;
            timeCurrent.textContent = '00:00';
        };
    }

    // ── Player: Play / Pause ──
    btnPlayPause.addEventListener('click', function() {
        if (!lastAudioBlob) return;
        if (audioPlayer.paused || audioPlayer.ended) {
            audioPlayer.play().catch(function(e) {
                console.warn('[VoxBox] Playback failed:', e);
            });
            btnPlayPause.textContent = '⏸';
        } else {
            audioPlayer.pause();
            btnPlayPause.textContent = '▶';
        }
    });

    // ── Player: Time update ──
    audioPlayer.addEventListener('timeupdate', function() {
        if (!playerSeeking && audioPlayer.duration) {
            var pct = (audioPlayer.currentTime / audioPlayer.duration) * 100;
            playerProgress.value = Math.floor(audioPlayer.currentTime * 100);
            timeCurrent.textContent = formatTime(audioPlayer.currentTime);
        }
    });

    audioPlayer.addEventListener('play', function() {
        btnPlayPause.textContent = '⏸';
    });

    audioPlayer.addEventListener('pause', function() {
        btnPlayPause.textContent = '▶';
    });

    // ── Player: Progress bar seek ──
    playerProgress.addEventListener('input', function() {
        playerSeeking = true;
        var seekTime = parseInt(playerProgress.value) / 100;
        timeCurrent.textContent = formatTime(seekTime);
    });

    playerProgress.addEventListener('change', function() {
        playerSeeking = false;
        var seekTime = parseInt(playerProgress.value) / 100;
        if (audioPlayer.duration) {
            audioPlayer.currentTime = seekTime;
        }
    });

    // ── Player: Replay ──
    btnReplay.addEventListener('click', function() {
        if (!lastAudioBlob) return;
        audioPlayer.currentTime = 0;
        audioPlayer.play().catch(function(e) {
            console.warn('[VoxBox] Replay failed:', e);
        });
    });

    // ── Player: Download ──
    btnDownloadAudio.addEventListener('click', function() {
        if (!lastAudioBlob) return;
        var url = URL.createObjectURL(lastAudioBlob);
        var a = document.createElement('a');
        a.href = url;
        var fname = (lastText || 'voxbox_audio').replace(/[^a-zA-Z0-9 _-]/g, '').trim() || 'voxbox_audio';
        a.download = fname + '.wav';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
    });

    // ── Core: call TTS API ──
    function callTTS(text) {
        var speed = parseFloat(speedSlider.value);
        var sampleRate = parseInt(sampleRateSlider.value);
        var cfg = parseFloat(cfgSlider.value);
        var timesteps = parseInt(timestepsSlider.value);
        var voice = voiceSelect.value;
        var voiceMode = voiceModeSelect.value;

        var body = {
            model: 'voxcpm2',
            input: text,
            speed: speed,
            sample_rate: sampleRate,
            cfg_value: cfg,
            inference_timesteps: timesteps,
            response_format: 'wav'
        };

        // Add voice parameters if a voice is selected
        if (voice) {
            body.voice = voice;
            body.voice_mode = voiceMode;
        }

        return fetch(SPEECH_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        }).then(function(response) {
            if (!response.ok) {
                return response.text().then(function(errText) {
                    throw new Error('Server returned ' + response.status + ': ' + (errText || 'Unknown error'));
                });
            }
            var contentType = response.headers.get('content-type') || '';
            if (contentType.indexOf('audio/') === -1) {
                return response.text().then(function(bodyText) {
                    throw new Error('Expected audio but got: ' + (bodyText || contentType));
                });
            }
            return response.blob();
        });
    }

    // ── Play audio from blob ──
    function playAudioBlob(blob) {
        var url = URL.createObjectURL(blob);
        audioPlayer.src = url;
        audioPlayer.play().catch(function(e) {
            console.warn('[VoxBox] Audio playback failed:', e);
        });
        audioPlayer.onended = function() {
            URL.revokeObjectURL(url);
            btnPlayPause.textContent = '▶';
        };
    }

    // ── Generate & Play ──
    btnGeneratePlay.addEventListener('click', function() {
        if (isGenerating) return;

        var text = textInput.value.trim();
        if (!text || text.length > 2000) return;

        lastText = text;
        setGenerating(true);
        setStatus('generating', 'Generating speech…');

        callTTS(text).then(function(blob) {
            lastAudioBlob = blob;
            setGenerating(false);
            setStatus('success', '✓ Audio generated — playing now');
            showPlayer(text, blob);
            playAudioBlob(blob);
        }).catch(function(err) {
            setGenerating(false);
            setStatus('error', '✗ ' + err.message);
            console.error('[VoxBox] TTS error:', err);
        });
    });

    // ── Generate & Save ──
    btnGenerateSave.addEventListener('click', function() {
        if (isGenerating) return;

        var text = textInput.value.trim();
        if (!text || text.length > 2000) return;

        lastText = text;
        setGenerating(true);
        setStatus('generating', 'Generating speech…');

        callTTS(text).then(function(blob) {
            lastAudioBlob = blob;
            setGenerating(false);
            setStatus('success', '✓ Audio saved to VoxBox Output');
            showPlayer(text, blob);
            showToast('🎵 Saved to VoxBox Output');
        }).catch(function(err) {
            setGenerating(false);
            setStatus('error', '✗ ' + err.message);
            console.error('[VoxBox] TTS error:', err);
        });
    });

    // ── Keyboard shortcut: ⌘↵ to generate & play ──
    textInput.addEventListener('keydown', function(e) {
        if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
            e.preventDefault();
            if (!isGenerating && textInput.value.trim()) {
                btnGeneratePlay.click();
            }
        }
    });

    // ── Init ──
    updateCharCount();
    textInput.focus();
    loadVoices();

    console.log('[VoxBox] Native frontend ready · Port ' + SERVER_PORT);
})();
</script>
</body>
</html>
"""
}

// MARK: - WebView

struct WebView: NSViewRepresentable {
    let port: Int
    /// (audioData, textUsed)
    var onAudioCaptured: ((Data, String) -> Void)? = nil
    /// User clicked save in the in-page notification
    var onSaveRequested: (() -> Void)? = nil
    /// User clicked save for a specific history item
    var onSaveHistoryItem: ((Int) -> Void)? = nil
    /// User clicked the clock icon to open output folder
    var onOpenRecordingsFolder: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.onAudioCaptured = onAudioCaptured
        context.coordinator.onSaveRequested = onSaveRequested
        context.coordinator.onSaveHistoryItem = onSaveHistoryItem
        context.coordinator.onOpenRecordingsFolder = onOpenRecordingsFolder

        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()

        // ── VoxBox bridge ──
        let bridgeScript = """
        window.voxbox = {
            platform: 'macOS',
            version: '\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")',
            getStatus: function() { return 'local-frontend'; },
            log: function(msg) { window.webkit.messageHandlers.voxbox.postMessage({type: 'log', message: msg}); }
        };
        """
        let bridgeUserScript = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(bridgeUserScript)
        userContentController.add(context.coordinator, name: "voxbox")

        // ── Audio capture hook (intercepts fetch to /v1/audio/speech) ──
        let captureScript = createCaptureScript()
        let captureUserScript = WKUserScript(source: captureScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(captureUserScript)
        userContentController.add(context.coordinator, name: "audioCaptured")

        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // ── Load local HTML ──
        let html = VoxBoxHTML.html(port: port)
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAudioCaptured = onAudioCaptured
        context.coordinator.onSaveRequested = onSaveRequested
        context.coordinator.onSaveHistoryItem = onSaveHistoryItem
        context.coordinator.onOpenRecordingsFolder = onOpenRecordingsFolder
    }

    // MARK: - JS Injection

    private func createCaptureScript() -> String {
        let zh = LocalizationManager.shared.isChinese
        let toastMsg = zh ? "🎵 已自动保存" : "🎵 Auto-saved"
        let openLabel = "📂"

        return """
(function() {
    'use strict';
    if (window.__voxboxInjected) return;
    window.__voxboxInjected = true;

    // ── Helpers ──
    function arrayBufferToBase64(buffer) {
        var bytes = new Uint8Array(buffer);
        var chunkSize = 8192;
        var chunks = [];
        for (var i = 0; i < bytes.length; i += chunkSize) {
            chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + chunkSize)));
        }
        return btoa(chunks.join(''));
    }

    function escapeHTML(str) {
        var div = document.createElement('div');
        div.textContent = str || '';
        return div.innerHTML;
    }

    // ── Inject minimal styles once ──
    function injectStyles() {
        if (document.getElementById('voxbox-styles')) return;
        var style = document.createElement('style');
        style.id = 'voxbox-styles';
        style.textContent = [
            '@keyframes voxboxSlideIn{from{transform:translateX(-50%) translateY(-12px);opacity:0}to{transform:translateX(-50%) translateY(0);opacity:1}}',
            '@keyframes voxboxSlideOut{from{transform:translateX(-50%) translateY(0);opacity:1}to{transform:translateX(-50%) translateY(-12px);opacity:0}}'
        ].join('');
        document.head.appendChild(style);
    }

    // ── Compact notification (top-center) ──
    function showNotification(text) {
        var existing = document.getElementById('voxbox-notification');
        if (existing) existing.remove();

        var displayText = text || 'Audio';
        if (displayText.length > 40) displayText = displayText.substring(0, 37) + '...';

        var notif = document.createElement('div');
        notif.id = 'voxbox-notification';
        notif.innerHTML =
            '<div style="display:flex;align-items:center;gap:6px;padding:5px 10px;' +
            'background:rgba(22,22,40,0.9);color:#e2e8f0;' +
            'border-radius:8px;font-size:11px;font-family:-apple-system,BlinkMacSystemFont,sans-serif;' +
            'box-shadow:0 3px 16px rgba(0,0,0,0.25);pointer-events:auto;max-width:400px;' +
            'border:1px solid rgba(255,255,255,0.07);line-height:1.4;">' +
            '<span style="white-space:nowrap;font-weight:500;">\(toastMsg)</span>' +
            '<span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#94a3b8;">· ' +
                escapeHTML(displayText) +
            '</span>' +
            '<button id="voxbox-notif-open" title="\(openLabel)" style="padding:2px 5px;background:rgba(255,255,255,0.08);color:#e2e8f0;border:1px solid rgba(255,255,255,0.1);' +
                'border-radius:5px;cursor:pointer;font-size:12px;line-height:1;transition:background 0.15s;">' +
                '\(openLabel)' +
            '</button>' +
            '<button id="voxbox-notif-close" style="padding:1px 3px;background:transparent;color:#94a3b8;' +
                'border:none;cursor:pointer;font-size:13px;line-height:1;transition:color 0.15s;">' +
                '✕' +
            '</button>' +
            '</div>';

        notif.style.cssText = [
            'position:fixed',
            'top:12px',
            'left:50%',
            'transform:translateX(-50%)',
            'z-index:2147483647',
            'pointer-events:none',
            'animation:voxboxSlideIn 0.25s ease-out'
        ].join(';');

        document.body.appendChild(notif);
        injectStyles();

        var openBtn = document.getElementById('voxbox-notif-open');
        var closeBtn = document.getElementById('voxbox-notif-close');

        openBtn.onmouseenter = function() { openBtn.style.background = 'rgba(255,255,255,0.15)'; };
        openBtn.onmouseleave = function() { openBtn.style.background = 'rgba(255,255,255,0.08)'; };
        openBtn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.voxbox) {
                window.webkit.messageHandlers.voxbox.postMessage({type: 'openRecordingsFolder'});
            }
        };

        closeBtn.onmouseenter = function() { closeBtn.style.color = '#e2e8f0'; };
        closeBtn.onmouseleave = function() { closeBtn.style.color = '#94a3b8'; };
        closeBtn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            dismissNotification(notif);
        };

        var timer = setTimeout(function() { dismissNotification(notif); }, 8000);
        notif._voxboxTimer = timer;
    }

    function dismissNotification(notif) {
        if (!notif || notif._voxboxDismissed) return;
        notif._voxboxDismissed = true;
        clearTimeout(notif._voxboxTimer);
        notif.style.animation = 'voxboxSlideOut 0.2s ease-in forwards';
        setTimeout(function() {
            if (notif.parentNode) notif.parentNode.removeChild(notif);
        }, 250);
    }

    // ── Fetch hook - capture /v1/audio/speech responses ──
    if (typeof window.fetch === 'function') {
        var _fetch = window.fetch;
        window.fetch = function() {
            var url = arguments[0];
            var urlStr = '';
            if (typeof url === 'string') urlStr = url;
            else if (url instanceof Request) urlStr = url.url;
            else urlStr = String(url);

            var inputText = '';
            if (urlStr.indexOf('/audio/speech') !== -1) {
                try {
                    var options = arguments[1];
                    if (options && typeof options.body === 'string') {
                        var body = JSON.parse(options.body);
                        inputText = body.input || '';
                    }
                } catch(e) {}
            }

            return _fetch.apply(this, arguments).then(function(response) {
                if (urlStr.indexOf('/audio/speech') !== -1 && response.ok) {
                    var ct = response.headers.get('content-type') || '';
                    if (ct.indexOf('audio/') !== -1) {
                        var clone = response.clone();
                        clone.arrayBuffer().then(function(buffer) {
                            var base64 = arrayBufferToBase64(buffer);

                            // Send to Swift (will auto-save)
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioCaptured) {
                                window.webkit.messageHandlers.audioCaptured.postMessage({
                                    data: base64,
                                    mimeType: ct,
                                    text: inputText
                                });
                            }

                            // Show compact notification
                            showNotification(inputText);
                        }).catch(function(e) {
                            console.log('[VoxBox] Audio capture error:', e);
                        });
                    }
                }
                return response;
            });
        };
    }

    console.log('[VoxBox] Capture bridge ready (fetch hook + auto-save)');
})();
"""
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onAudioCaptured: ((Data, String) -> Void)?
        var onSaveRequested: (() -> Void)?
        var onSaveHistoryItem: ((Int) -> Void)?
        var onOpenRecordingsFolder: (() -> Void)?
        var isLoading = false

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            print("✅ WebView loaded: local frontend")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            print("❌ WebView failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            print("⚠️ WebView provisional load failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "voxbox":
                guard let body = message.body as? [String: Any],
                      let type = body["type"] as? String else { return }
                if type == "log", let msg = body["message"] as? String {
                    print("🌐 [WebView] \(msg)")
                } else if type == "saveAudio" {
                    DispatchQueue.main.async { [weak self] in
                        self?.onSaveRequested?()
                    }
                } else if type == "saveAudioAtIndex", let idx = body["index"] as? Int {
                    DispatchQueue.main.async { [weak self] in
                        self?.onSaveHistoryItem?(idx)
                    }
                } else if type == "openRecordingsFolder" {
                    DispatchQueue.main.async { [weak self] in
                        self?.onOpenRecordingsFolder?()
                    }
                }

            case "audioCaptured":
                guard let body = message.body as? [String: Any],
                      let base64 = body["data"] as? String,
                      let audioData = Data(base64Encoded: base64) else {
                    print("⚠️ [VoxBox] Failed to decode captured audio")
                    return
                }
                let text = body["text"] as? String ?? ""
                print("🎵 [VoxBox] Audio captured: \(audioData.count) bytes, text: \"\(text.prefix(40))\"")
                DispatchQueue.main.async { [weak self] in
                    self?.onAudioCaptured?(audioData, text)
                }

            default:
                break
            }
        }
    }
}
