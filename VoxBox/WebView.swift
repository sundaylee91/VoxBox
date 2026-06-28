import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - VoxBox Local Frontend HTML

enum VoxBoxHTML {
    /// Returns the full HTML document with the server port and language injected.
    static func html(port: Int, isChinese: Bool) -> String {
        var html = template
        html = html.replacingOccurrences(of: "{{PORT}}", with: "\(port)")
        html = html.replacingOccurrences(of: "{{IS_CHINESE}}", with: isChinese ? "true" : "false")
        return html
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
        --btn-disabled-bg: rgba(0,0,0,0.04);
        --btn-disabled-text: rgba(0,0,0,0.22);
        --btn-disabled-border: rgba(0,0,0,0.06);
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
            --btn-disabled-bg: rgba(255,255,255,0.04);
            --btn-disabled-text: rgba(255,255,255,0.18);
            --btn-disabled-border: rgba(255,255,255,0.05);
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

    /* ── Audio Player (inside card, above textarea) ── */
    .player-card {
        background: var(--player-bg);
        border: 1px solid var(--card-border);
        border-radius: 14px;
        display: none;
        flex-direction: column;
        gap: 0;
        overflow: hidden;
    }

    .player-card.visible {
        display: flex;
    }

    .player-progress-row {
        width: 100%;
        display: flex;
        align-items: center;
        padding: 14px 16px 6px 16px;
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
        margin: 0;
    }

    .player-progress::-webkit-slider-thumb {
        -webkit-appearance: none;
        width: 18px;
        height: 18px;
        border-radius: 50%;
        background: var(--slider-fill);
        border: 2px solid #ffffff;
        box-shadow: 0 1px 6px rgba(0,0,0,0.18);
        cursor: pointer;
    }

    .player-controls-row {
        display: flex;
        align-items: center;
        gap: 10px;
        width: 100%;
        padding: 4px 16px 12px 16px;
    }

    .player-filename {
        flex: 1;
        font-size: 12px;
        font-weight: 500;
        color: var(--text-secondary);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        min-width: 0;
        letter-spacing: -0.1px;
    }

    .player-times-inline {
        font-size: 11px;
        font-weight: 500;
        color: var(--text-tertiary);
        white-space: nowrap;
        flex-shrink: 0;
        letter-spacing: 0;
        font-variant-numeric: tabular-nums;
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

    .voice-preset-btn {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 32px;
        height: 32px;
        background: var(--input-bg);
        color: var(--text-secondary);
        border: 1.5px solid var(--input-border);
        border-radius: 8px;
        cursor: pointer;
        font-size: 14px;
        transition: all 0.15s ease;
        flex-shrink: 0;
    }

    .voice-preset-btn:hover {
        background: var(--btn-secondary-hover-bg);
        border-color: rgba(0,122,255,0.3);
    }

    .voice-preset-btn.danger:hover {
        border-color: #FF453A;
        color: #FF453A;
        background: rgba(255,69,58,0.06);
    }

    .voice-preset-btn:disabled {
        opacity: 0.35;
        cursor: not-allowed;
        pointer-events: none;
    }

    /* ── Toggle Group (Create Voice + Advanced Settings) ── */
    .toggle-group {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    /* ── Advanced Settings Toggle ── */
    .advanced-toggle {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 13px;
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
        padding: 6px 0;
    }

    .advanced-panel.open {
        max-height: 500px;
        opacity: 1;
        margin-top: 2px;
    }

    .advanced-panel.create-voice-panel.open {
        max-height: 400px;
    }

    .setting-row {
        display: flex;
        align-items: center;
        justify-content: flex-start;
        gap: 10px;
    }

    .setting-label {
        font-size: 13px;
        font-weight: 500;
        color: var(--text-secondary);
        white-space: nowrap;
        letter-spacing: -0.1px;
        min-width: 88px;
    }

    .setting-value {
        font-size: 12px;
        font-weight: 600;
        color: var(--text-primary);
        min-width: 44px;
        text-align: right;
    }

    /* ── Slider ── */
    .setting-row input[type="range"] {
        -webkit-appearance: none;
        appearance: none;
        width: 130px;
        height: 6px;
        border-radius: 3px;
        background: var(--slider-track);
        outline: none;
        cursor: pointer;
        flex-shrink: 0;
    }

    .setting-row input[type="range"]::-webkit-slider-thumb {
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

    .setting-row input[type="range"]::-webkit-slider-thumb:active {
        box-shadow: 0 0 0 6px rgba(0,122,255,0.18);
    }

    /* ── Create Voice Inputs ── */
    .create-voice-input {
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
        transition: border-color 0.2s ease;
        -webkit-appearance: none;
    }

    .create-voice-input:focus {
        border-color: var(--input-focus-border);
    }

    .create-voice-textarea {
        flex: 1;
        min-height: 50px;
        padding: 8px 12px;
        font-family: inherit;
        font-size: 13px;
        font-weight: 400;
        line-height: 1.4;
        color: var(--text-primary);
        background: var(--input-bg);
        border: 1.5px solid var(--input-border);
        border-radius: 10px;
        resize: vertical;
        outline: none;
        transition: border-color 0.2s ease;
        -webkit-appearance: none;
    }

    .create-voice-textarea:focus {
        border-color: var(--input-focus-border);
    }

    .pick-audio-btn {
        padding: 8px 14px;
        font-family: inherit;
        font-size: 12px;
        font-weight: 600;
        color: var(--text-primary);
        background: var(--input-bg);
        border: 1.5px solid var(--input-border);
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.15s ease;
        white-space: nowrap;
    }

    .pick-audio-btn:hover {
        border-color: rgba(0,122,255,0.3);
        background: var(--btn-secondary-hover-bg);
    }

    .audio-path-display {
        flex: 1;
        font-size: 11px;
        font-weight: 500;
        color: var(--text-tertiary);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        min-width: 0;
    }

    .create-voice-status {
        font-size: 11px;
        font-weight: 500;
        min-height: 16px;
        line-height: 16px;
        text-align: center;
        transition: color 0.3s ease;
    }

    .create-voice-status.idle { color: var(--text-tertiary); }
    .create-voice-status.creating { color: var(--status-info); }
    .create-voice-status.success { color: var(--status-success); }
    .create-voice-status.error { color: var(--status-error); }

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
        opacity: 0.35;
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

    .btn-create-voice {
        width: 100%;
        padding: 10px 20px;
        font-family: inherit;
        font-size: 13px;
        font-weight: 600;
        color: #ffffff;
        background: linear-gradient(135deg, #30D158 0%, #34C759 100%);
        border: none;
        border-radius: 10px;
        cursor: pointer;
        transition: all 0.2s ease;
        box-shadow: 0 2px 10px rgba(48,209,88,0.25);
    }

    .btn-create-voice:hover:not(:disabled) {
        transform: translateY(-1px);
        box-shadow: 0 4px 18px rgba(48,209,88,0.35);
    }

    .btn-create-voice:disabled {
        opacity: 0.4;
        cursor: not-allowed;
        pointer-events: none;
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

    /* ── Toast (larger) ── */
    @keyframes toastIn {
        from { transform: translateX(-50%) translateY(-16px); opacity: 0; }
        to { transform: translateX(-50%) translateY(0); opacity: 1; }
    }
    @keyframes toastOut {
        from { transform: translateX(-50%) translateY(0); opacity: 1; }
        to { transform: translateX(-50%) translateY(-16px); opacity: 0; }
    }

    .toast {
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        z-index: 9999;
        padding: 14px 28px;
        background: var(--toast-bg);
        color: var(--toast-text);
        font-size: 15px;
        font-weight: 500;
        border-radius: 14px;
        box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        backdrop-filter: blur(16px);
        -webkit-backdrop-filter: blur(16px);
        pointer-events: none;
        animation: toastIn 0.3s ease-out forwards;
        letter-spacing: -0.1px;
        line-height: 1.4;
    }

    .toast.out {
        animation: toastOut 0.25s ease-in forwards;
    }

    /* ── Hidden audio element ── */
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
        <h1 data-l10n="appTitle">VoxBox</h1>
        <p class="subtitle" data-l10n="appSubtitle">Native AI Text-to-Speech on Apple Neural Engine</p>
    </div>

    <!-- Main Card -->
    <div class="card">
        <!-- Audio Player (above text input) -->
        <div class="player-card" id="player-card">
            <div class="player-progress-row">
                <input type="range" class="player-progress" id="player-progress" min="0" max="100" value="0">
            </div>
            <div class="player-controls-row">
                <button class="player-btn play-btn" id="btn-play-pause" data-l10n-title="playPause" title="播放 / 暂停">▶</button>
                <span class="player-filename" id="player-filename"></span>
                <span class="player-times-inline" id="player-times-inline">00:00 / 00:00</span>
                <button class="player-btn" id="btn-replay" data-l10n-title="replay" title="重新播放">↺</button>
            </div>
        </div>

        <!-- Text Input -->
        <div class="input-wrapper">
            <textarea
                id="text-input"
                data-l10n-placeholder="inputPlaceholder"
                placeholder="Type or paste text to speak…"
                maxlength="2000"
                rows="4"
            ></textarea>
            <div class="input-footer">
                <span class="char-count" id="char-count">0 / 2000</span>
                <button class="clear-btn" id="clear-btn" data-l10n="clearBtn" title="Clear text">Clear</button>
            </div>
        </div>

        <!-- Voice Preset -->
        <div class="voice-section">
            <div class="setting-row">
                <span class="setting-label" data-l10n="voiceLabel">🎤 语音</span>
                <button class="voice-refresh" id="voice-refresh" data-l10n-title="refreshVoices" title="Refresh voices">↻</button>
            </div>
            <div class="voice-row">
                <select id="voice-select" class="voice-select">
                    <option value="" data-l10n="loadingVoices">加载中…</option>
                </select>
                <select id="voice-mode-select" class="voice-mode-select">
                    <option value="reference">Reference</option>
                    <option value="high_similarity" data-l10n="highSim">高相似度</option>
                </select>
                <button class="voice-preset-btn danger" id="btn-delete-server-voice" data-l10n-title="deleteServerVoice" title="删除服务器端自定义语音" disabled>🗑</button>
            </div>
        </div>

        <!-- Toggle Group: Create Voice + Advanced Settings -->
        <div class="toggle-group">
            <!-- Create Voice Section -->
            <button class="advanced-toggle" id="create-voice-toggle">
                <span data-l10n="createVoiceTitle">🎙 创建新语音</span>
                <span class="chevron">▾</span>
            </button>

            <div class="advanced-panel create-voice-panel" id="create-voice-panel">
                <div class="setting-row">
                    <span class="setting-label" data-l10n="voiceName">语音名称</span>
                    <input type="text" id="new-voice-name" class="create-voice-input" placeholder="如: my-voice" maxlength="60">
                </div>
                <div class="setting-row">
                    <span class="setting-label" data-l10n="refAudio">参考音频</span>
                    <button class="pick-audio-btn" id="btn-pick-audio" data-l10n="chooseFile">选择文件…</button>
                    <span class="audio-path-display" id="audio-path-display"></span>
                </div>
                <div class="setting-row">
                    <span class="setting-label" data-l10n="promptText">转录文本</span>
                    <textarea id="new-voice-text" class="create-voice-textarea" placeholder="可选：精确转录文本（用于高相似度克隆）"></textarea>
                </div>
                <div class="setting-row">
                    <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--text-tertiary);cursor:pointer;">
                        <input type="checkbox" id="new-voice-replace" style="width:14px;height:14px;">
                        <span data-l10n="replaceIfExists">替换已存在的语音</span>
                    </label>
                </div>
                <button class="btn-create-voice" id="btn-create-voice">
                    <span id="btn-create-voice-text" data-l10n="createVoice">Create Voice</span>
                </button>
                <div class="create-voice-status idle" id="create-voice-status" data-l10n="createVoiceHint">选择参考音频文件，输入名称后点击创建</div>
            </div>

            <!-- Advanced Settings Toggle -->
            <button class="advanced-toggle" id="advanced-toggle">
                <span data-l10n="advancedSettings">⚙ 高级设置</span>
                <span class="chevron">▾</span>
            </button>

            <!-- Advanced Panel -->
            <div class="advanced-panel" id="advanced-panel">
                <div class="setting-row">
                    <span class="setting-label" data-l10n="cfgScale">CFG 缩放</span>
                    <input type="range" id="cfg-slider" min="1.0" max="4.0" step="0.1" value="2.0">
                    <span class="setting-value" id="cfg-value">2.0</span>
                </div>
                <div class="setting-row">
                    <span class="setting-label" data-l10n="timesteps">推理步数</span>
                    <input type="range" id="timesteps-slider" min="4" max="30" step="1" value="10">
                    <span class="setting-value" id="timesteps-value">10</span>
                </div>
                <div class="setting-row">
                    <span class="setting-label" data-l10n="seed">随机种子</span>
                    <input type="number" id="seed-input" min="-1" max="999999" step="1" value="-1" style="width:80px;padding:4px 8px;font-family:inherit;font-size:13px;color:var(--text-primary);background:var(--input-bg);border:1.5px solid var(--input-border);border-radius:8px;outline:none;text-align:center;">
                    <button class="pick-audio-btn" id="btn-randomize-seed" data-l10n="randomize" style="font-size:11px;padding:4px 10px;">随机</button>
                </div>
                <div class="setting-row">
                    <span class="setting-label" data-l10n="maxLength">最大 Token 数</span>
                    <input type="range" id="max-length-slider" min="128" max="4096" step="128" value="2048">
                    <span class="setting-value" id="max-length-value">2048</span>
                </div>
            </div>
        </div>

        <!-- Action Buttons -->
        <div class="btn-row">
            <button class="btn btn-primary" id="btn-generate-play" disabled>
                <span id="btn-icon-play">▶</span>
                <span id="btn-text-play" data-l10n="generateAndPlay">生成并播放</span>
            </button>
            <button class="btn btn-secondary" id="btn-generate-save" disabled>
                <span>💾</span>
                <span data-l10n="saveAudio">保存音频</span>
            </button>
        </div>

        <!-- Status -->
        <div class="status idle" id="status" data-l10n="ready">就绪</div>
    </div>
</div>

<!-- Hidden audio player -->
<audio id="audio-player" preload="auto"></audio>

<script>
(function() {
    'use strict';

    // ── Localization ──
    var IS_CHINESE = {{IS_CHINESE}};

    var L10N = {
        appTitle: IS_CHINESE ? 'VoxBox' : 'VoxBox',
        appSubtitle: IS_CHINESE ? '基于 Apple 神经网络引擎的原生 AI 文字转语音' : 'Native AI Text-to-Speech on Apple Neural Engine',
        inputPlaceholder: IS_CHINESE ? '输入或粘贴要朗读的文字…' : 'Type or paste text to speak…',
        clearBtn: IS_CHINESE ? '清空' : 'Clear',
        clearBtnTitle: IS_CHINESE ? '清空文字' : 'Clear text',
        voiceLabel: IS_CHINESE ? '🎤 语音' : '🎤 Voice',
        refreshVoices: IS_CHINESE ? '刷新语音列表' : 'Refresh voices',
        loadingVoices: IS_CHINESE ? '加载中…' : 'Loading voices…',
        defaultVoice: IS_CHINESE ? '默认（无预设）' : 'Default (no preset)',
        noVoices: IS_CHINESE ? '未找到预设语音' : 'No preset voices found',
        loadFailed: IS_CHINESE ? '加载失败' : 'Failed to load voices',
        highSim: IS_CHINESE ? '高相似度' : 'High Sim',
        deleteServerVoice: IS_CHINESE ? '删除服务器端自定义语音' : 'Delete server-side custom voice',
        voiceDeleted: IS_CHINESE ? '自定义语音已删除' : 'Custom voice deleted',
        deleteVoiceConfirm: IS_CHINESE ? '确定要永久删除该自定义语音吗？此操作不可撤销。' : 'Delete this custom voice permanently? This cannot be undone.',
        advancedSettings: IS_CHINESE ? '⚙ 高级设置' : '⚙ Advanced Settings',
        cfgScale: IS_CHINESE ? 'CFG 缩放' : 'CFG Scale',
        timesteps: IS_CHINESE ? '推理步数' : 'Timesteps',
        seed: IS_CHINESE ? '随机种子' : 'Seed',
        maxLength: IS_CHINESE ? '最大 Token 数' : 'Max Tokens',
        randomize: IS_CHINESE ? '随机' : 'Random',
        generateAndPlay: IS_CHINESE ? '生成并播放' : 'Generate & Play',
        saveAudio: IS_CHINESE ? '保存音频' : 'Save Audio',
        ready: IS_CHINESE ? '就绪' : 'Ready',
        generating: IS_CHINESE ? '正在生成语音…' : 'Generating speech…',
        successPlay: IS_CHINESE ? '✓ 音频已生成' : '✓ Audio generated',
        successSaved: IS_CHINESE ? '✓ 音频已保存' : '✓ Audio saved',
        errorPrefix: IS_CHINESE ? '✗ ' : '✗ ',
        playPause: IS_CHINESE ? '播放 / 暂停' : 'Play / Pause',
        replay: IS_CHINESE ? '重新播放' : 'Replay',
        generatedAudio: IS_CHINESE ? '生成的音频' : 'Generated Audio',
        toastSaved: IS_CHINESE ? '💾 音频已保存至 ' : '💾 Audio saved to ',
        toastVoxBoxOutput: IS_CHINESE ? 'VoxBox Output 文件夹' : 'VoxBox Output folder',
        // Create Voice L10N
        createVoiceTitle: IS_CHINESE ? '🎙 创建新语音' : '🎙 Create Voice',
        voiceName: IS_CHINESE ? '语音名称' : 'Voice Name',
        refAudio: IS_CHINESE ? '参考音频' : 'Reference Audio',
        promptText: IS_CHINESE ? '转录文本' : 'Transcription',
        chooseFile: IS_CHINESE ? '选择文件…' : 'Choose File…',
        replaceIfExists: IS_CHINESE ? '替换已存在的语音' : 'Replace if exists',
        createVoice: IS_CHINESE ? 'Create Voice' : 'Create Voice',
        creatingVoice: IS_CHINESE ? '正在创建…' : 'Creating…',
        voiceCreated: IS_CHINESE ? '✓ 语音已创建' : '✓ Voice created',
        createVoiceHint: IS_CHINESE ? '选择参考音频文件，输入名称后点击创建' : 'Select a reference audio file, enter a name, and click Create',
        noAudioFile: IS_CHINESE ? '请先选择参考音频文件' : 'Please select a reference audio file first',
        noVoiceName: IS_CHINESE ? '请输入语音名称' : 'Please enter a voice name',
        customVoiceBadge: IS_CHINESE ? '自定义' : 'custom',
        // Dropdown separators
        sepCustomVoices: IS_CHINESE ? '──── 自定义语音 ────' : '──── Custom Voices ────',
        sepPresets: IS_CHINESE ? '──── 参数预设 ────' : '──── Parameter Presets ────'
    };

    function _(key) { return L10N[key] || key; }

    function applyL10n() {
        document.querySelectorAll('[data-l10n]').forEach(function(el) {
            var key = el.getAttribute('data-l10n');
            if (L10N[key]) el.textContent = L10N[key];
        });
        document.querySelectorAll('[data-l10n-placeholder]').forEach(function(el) {
            var key = el.getAttribute('data-l10n-placeholder');
            if (L10N[key]) el.placeholder = L10N[key];
        });
        document.querySelectorAll('[data-l10n-title]').forEach(function(el) {
            var key = el.getAttribute('data-l10n-title');
            if (L10N[key]) el.title = L10N[key];
        });
        var clearBtn = document.getElementById('clear-btn');
        if (clearBtn) clearBtn.title = _('clearBtnTitle');
    }

    // ── Configuration ──
    var SERVER_PORT = {{PORT}};
    var API_BASE = 'http://127.0.0.1:' + SERVER_PORT;
    var SPEECH_ENDPOINT = API_BASE + '/v1/audio/speech';
    var VOICES_ENDPOINT = API_BASE + '/voices';
    var CREATE_VOICE_ENDPOINT = API_BASE + '/v1/voices';

    // ── DOM refs ──
    var textInput = document.getElementById('text-input');
    var charCount = document.getElementById('char-count');
    var clearBtn = document.getElementById('clear-btn');
    var advancedToggle = document.getElementById('advanced-toggle');
    var advancedPanel = document.getElementById('advanced-panel');
    var cfgSlider = document.getElementById('cfg-slider');
    var cfgValue = document.getElementById('cfg-value');
    var timestepsSlider = document.getElementById('timesteps-slider');
    var timestepsValue = document.getElementById('timesteps-value');
    var seedInput = document.getElementById('seed-input');
    var btnRandomizeSeed = document.getElementById('btn-randomize-seed');
    var maxLengthSlider = document.getElementById('max-length-slider');
    var maxLengthValue = document.getElementById('max-length-value');
    var voiceSelect = document.getElementById('voice-select');
    var voiceModeSelect = document.getElementById('voice-mode-select');
    var voiceRefresh = document.getElementById('voice-refresh');
    var btnDeleteServerVoice = document.getElementById('btn-delete-server-voice');
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
    var playerTimesInline = document.getElementById('player-times-inline');
    var btnReplay = document.getElementById('btn-replay');

    // ── Create Voice DOM refs ──
    var createVoiceToggle = document.getElementById('create-voice-toggle');
    var createVoicePanel = document.getElementById('create-voice-panel');
    var newVoiceNameInput = document.getElementById('new-voice-name');
    var newVoiceTextInput = document.getElementById('new-voice-text');
    var newVoiceReplaceCheckbox = document.getElementById('new-voice-replace');
    var btnPickAudio = document.getElementById('btn-pick-audio');
    var audioPathDisplay = document.getElementById('audio-path-display');
    var btnCreateVoice = document.getElementById('btn-create-voice');
    var btnCreateVoiceText = document.getElementById('btn-create-voice-text');
    var createVoiceStatus = document.getElementById('create-voice-status');

    // ── State ──
    var isGenerating = false;
    var lastAudioBlob = null;
    var lastText = '';
    var availableVoices = [];
    var serverCustomVoices = [];
    var playerSeeking = false;
    var currentBlobURL = null;
    var localStoragePresets = [];
    var LOCAL_PRESETS_KEY = 'voxbox_custom_voices';
    var _suppressVoiceChange = false;
    var selectedAudioPath = '';
    var isCreatingVoice = false;

    // ── Format time ──
    function formatTime(seconds) {
        if (isNaN(seconds) || !isFinite(seconds)) return '00:00';
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }

    // ── LocalStorage Presets (load only, for backward compat) ──
    function loadLocalPresets() {
        try {
            var raw = localStorage.getItem(LOCAL_PRESETS_KEY);
            localStoragePresets = raw ? JSON.parse(raw) : [];
            if (!Array.isArray(localStoragePresets)) localStoragePresets = [];
        } catch(e) {
            localStoragePresets = [];
        }
    }

    function applySettings(settings) {
        if (!settings) return;
        _suppressVoiceChange = true;
        try {
            if (settings.voice !== undefined) {
                if (availableVoices.indexOf(settings.voice) >= 0) {
                    voiceSelect.value = settings.voice;
                    voiceSelect.setAttribute('data-is-custom', 'false');
                    voiceSelect.setAttribute('data-is-server-custom', serverCustomVoices.indexOf(settings.voice) >= 0 ? 'true' : 'false');
                } else {
                    voiceSelect.value = '';
                    voiceSelect.setAttribute('data-is-custom', 'false');
                    voiceSelect.setAttribute('data-is-server-custom', 'false');
                }
            }
            if (settings.voice_mode !== undefined) voiceModeSelect.value = settings.voice_mode;
            if (settings.cfg_value !== undefined) {
                cfgSlider.value = settings.cfg_value;
                cfgValue.textContent = settings.cfg_value.toFixed(1);
            }
            if (settings.inference_timesteps !== undefined) {
                timestepsSlider.value = settings.inference_timesteps;
                timestepsValue.textContent = settings.inference_timesteps;
            }
        } finally {
            _suppressVoiceChange = false;
        }
    }

    function isServerCustomSelected() {
        return voiceSelect.getAttribute('data-is-server-custom') === 'true';
    }

    function updateDeleteButton() {
        btnDeleteServerVoice.disabled = !isServerCustomSelected();
    }

    // Rebuild voice dropdown with localized separators
    function refreshVoiceDropdown() {
        var sel = voiceSelect;
        var currentVal = sel.value;
        var isPreset = sel.getAttribute('data-is-custom') === 'true';
        var presetIdx = isPreset ? parseInt(sel.getAttribute('data-custom-idx')) : -1;

        _suppressVoiceChange = true;
        try {
            sel.innerHTML = '';

            var defaultOpt = document.createElement('option');
            defaultOpt.value = '';
            defaultOpt.textContent = _('defaultVoice');
            sel.appendChild(defaultOpt);

            // Server system voices
            availableVoices.forEach(function(name) {
                if (serverCustomVoices.indexOf(name) >= 0) return;
                var opt = document.createElement('option');
                opt.value = name;
                opt.textContent = name;
                sel.appendChild(opt);
            });

            // Server custom voices
            if (serverCustomVoices.length > 0) {
                var sep1 = document.createElement('option');
                sep1.value = '';
                sep1.textContent = _('sepCustomVoices');
                sep1.disabled = true;
                sel.appendChild(sep1);

                serverCustomVoices.forEach(function(name) {
                    var opt = document.createElement('option');
                    opt.value = name;
                    opt.textContent = '⭐ ' + name + ' (' + _('customVoiceBadge') + ')';
                    sel.appendChild(opt);
                });
            }

            // LocalStorage presets
            if (localStoragePresets.length > 0) {
                var sep2 = document.createElement('option');
                sep2.value = '';
                sep2.textContent = _('sepPresets');
                sep2.disabled = true;
                sel.appendChild(sep2);

                localStoragePresets.forEach(function(cv, idx) {
                    var opt = document.createElement('option');
                    opt.value = '__preset__' + idx;
                    opt.textContent = '💾 ' + cv.name;
                    sel.appendChild(opt);
                });
            }

            // Restore selection
            if (presetIdx >= 0 && presetIdx < localStoragePresets.length) {
                sel.value = '__preset__' + presetIdx;
                sel.setAttribute('data-is-custom', 'true');
                sel.setAttribute('data-custom-idx', String(presetIdx));
                sel.setAttribute('data-is-server-custom', 'false');
            } else if (serverCustomVoices.indexOf(currentVal) >= 0) {
                sel.value = currentVal;
                sel.setAttribute('data-is-custom', 'false');
                sel.setAttribute('data-is-server-custom', 'true');
            } else if (availableVoices.indexOf(currentVal) >= 0 || currentVal === '') {
                sel.value = currentVal;
                sel.setAttribute('data-is-custom', 'false');
                sel.setAttribute('data-is-server-custom', 'false');
            } else {
                sel.value = '';
                sel.setAttribute('data-is-custom', 'false');
                sel.setAttribute('data-is-server-custom', 'false');
            }
        } finally {
            _suppressVoiceChange = false;
        }

        updateDeleteButton();
    }

    // Voice select change
    voiceSelect.addEventListener('change', function() {
        if (_suppressVoiceChange) return;

        var val = voiceSelect.value;
        if (val && val.indexOf('__preset__') === 0) {
            var idx = parseInt(val.substring('__preset__'.length));
            voiceSelect.setAttribute('data-is-custom', 'true');
            voiceSelect.setAttribute('data-custom-idx', String(idx));
            voiceSelect.setAttribute('data-is-server-custom', 'false');

            if (idx >= 0 && idx < localStoragePresets.length) {
                var preset = localStoragePresets[idx];
                applySettings(preset);
                voiceSelect.setAttribute('data-is-custom', 'true');
                voiceSelect.setAttribute('data-custom-idx', String(idx));
                voiceSelect.setAttribute('data-is-server-custom', 'false');
            }
        } else if (val && serverCustomVoices.indexOf(val) >= 0) {
            voiceSelect.setAttribute('data-is-custom', 'false');
            voiceSelect.setAttribute('data-is-server-custom', 'true');
        } else {
            voiceSelect.setAttribute('data-is-custom', 'false');
            voiceSelect.setAttribute('data-is-server-custom', 'false');
        }
        updateDeleteButton();
    });

    // Delete server-side custom voice
    btnDeleteServerVoice.addEventListener('click', function() {
        var voiceName = voiceSelect.value;
        if (!voiceName || serverCustomVoices.indexOf(voiceName) < 0) return;

        if (!confirm(_('deleteVoiceConfirm'))) return;

        btnDeleteServerVoice.disabled = true;
        var origText = btnDeleteServerVoice.textContent;
        btnDeleteServerVoice.textContent = '…';

        fetch(CREATE_VOICE_ENDPOINT + '/' + encodeURIComponent(voiceName), {
            method: 'DELETE'
        })
        .then(function(response) {
            if (!response.ok) {
                return response.json().then(function(err) {
                    throw new Error(err.detail || 'HTTP ' + response.status);
                });
            }
            return response.json();
        })
        .then(function() {
            showToast(_('voiceDeleted') + ': ' + voiceName);
            loadVoices();
        })
        .catch(function(err) {
            showToast(_('errorPrefix') + err.message);
            console.error('[VoxBox] Delete voice error:', err);
        })
        .finally(function() {
            btnDeleteServerVoice.textContent = origText;
            updateDeleteButton();
        });
    });

    // ── Create Voice: File Picker Bridge ──
    btnPickAudio.addEventListener('click', function() {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.voxbox) {
            window.webkit.messageHandlers.voxbox.postMessage({type: 'pickAudioFile'});
        } else {
            showToast('File picker requires native app bridge');
        }
    });

    window.__voxboxOnAudioFilePicked = function(filePath) {
        selectedAudioPath = filePath;
        if (filePath) {
            var parts = filePath.split('/');
            audioPathDisplay.textContent = '📁 ' + (parts[parts.length - 1] || filePath);
            audioPathDisplay.style.color = 'var(--text-secondary)';
        } else {
            selectedAudioPath = '';
            audioPathDisplay.textContent = '';
        }
        updateCreateVoiceButton();
    };

    function updateCreateVoiceButton() {
        var hasName = newVoiceNameInput.value.trim().length > 0;
        var hasAudio = selectedAudioPath.length > 0;
        btnCreateVoice.disabled = !hasName || !hasAudio || isCreatingVoice;
    }

    newVoiceNameInput.addEventListener('input', updateCreateVoiceButton);

    // Create Voice: call server API
    btnCreateVoice.addEventListener('click', function() {
        var name = newVoiceNameInput.value.trim();
        if (!name) {
            showToast(_('noVoiceName'));
            return;
        }
        if (!selectedAudioPath) {
            showToast(_('noAudioFile'));
            return;
        }

        isCreatingVoice = true;
        btnCreateVoice.disabled = true;
        btnCreateVoiceText.textContent = _('creatingVoice');
        createVoiceStatus.className = 'create-voice-status creating';
        createVoiceStatus.textContent = IS_CHINESE ? '正在创建语音…' : 'Creating voice…';

        var body = {
            voice_name: name,
            reference_wav_path: selectedAudioPath
        };

        var promptText = newVoiceTextInput.value.trim();
        if (promptText) {
            body.prompt_text = promptText;
        }

        if (newVoiceReplaceCheckbox.checked) {
            body.replace = true;
        }

        fetch(CREATE_VOICE_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        })
        .then(function(response) {
            if (!response.ok) {
                return response.json().then(function(err) {
                    throw new Error(err.detail || 'HTTP ' + response.status);
                });
            }
            return response.json();
        })
        .then(function(result) {
            createVoiceStatus.className = 'create-voice-status success';
            createVoiceStatus.textContent = _('voiceCreated') + ': ' + name;
            showToast(_('voiceCreated') + ': ' + name);

            newVoiceNameInput.value = '';
            newVoiceTextInput.value = '';
            selectedAudioPath = '';
            audioPathDisplay.textContent = '';
            newVoiceReplaceCheckbox.checked = false;

            loadVoices().then(function() {
                _suppressVoiceChange = true;
                try {
                    voiceSelect.value = name;
                    voiceSelect.setAttribute('data-is-custom', 'false');
                    voiceSelect.setAttribute('data-is-server-custom', 'true');
                } finally {
                    _suppressVoiceChange = false;
                }
                updateDeleteButton();
            });

            setTimeout(function() {
                createVoicePanel.classList.remove('open');
                createVoiceToggle.classList.remove('open');
            }, 1500);
        })
        .catch(function(err) {
            createVoiceStatus.className = 'create-voice-status error';
            createVoiceStatus.textContent = _('errorPrefix') + err.message;
            console.error('[VoxBox] Create voice error:', err);
        })
        .finally(function() {
            isCreatingVoice = false;
            btnCreateVoice.disabled = false;
            btnCreateVoiceText.textContent = _('createVoice');
            updateCreateVoiceButton();
        });
    });

    // Create Voice toggle
    createVoiceToggle.addEventListener('click', function() {
        var isOpen = createVoicePanel.classList.toggle('open');
        createVoiceToggle.classList.toggle('open', isOpen);
    });

    // ── Load available voices ──
    function loadVoices() {
        voiceSelect.innerHTML = '<option value="">' + _('loadingVoices') + '</option>';
        voiceSelect.disabled = true;

        return fetch(VOICES_ENDPOINT)
            .then(function(response) {
                if (!response.ok) throw new Error('HTTP ' + response.status);
                return response.json();
            })
            .then(function(data) {
                availableVoices = [];
                serverCustomVoices = [];

                if (data && data.voices && Array.isArray(data.voices)) {
                    data.voices.forEach(function(v) {
                        var name = typeof v === 'string' ? v : (v.name || v.voice_name || '');
                        if (name) {
                            availableVoices.push(name);
                        }
                    });
                }

                if (data && data.custom_voices && Array.isArray(data.custom_voices)) {
                    serverCustomVoices = data.custom_voices;
                }

                voiceSelect.disabled = false;
                refreshVoiceDropdown();
                console.log('[VoxBox] Loaded ' + availableVoices.length + ' voices (' + serverCustomVoices.length + ' custom)');
            })
            .catch(function(err) {
                voiceSelect.disabled = false;
                refreshVoiceDropdown();
                console.warn('[VoxBox] Voice load error:', err);
            });
    }

    voiceRefresh.addEventListener('click', function() {
        loadVoices();
    });

    // ── Character count ──
    function updateCharCount() {
        var len = textInput.value.length;
        var max = 2000;
        charCount.textContent = len + ' / ' + max;
        charCount.classList.remove('warn', 'over');
        if (len > max * 0.85 && len <= max) charCount.classList.add('warn');
        if (len > max) charCount.classList.add('over');

        if (len > 0) {
            clearBtn.classList.add('visible');
        } else {
            clearBtn.classList.remove('visible');
        }

        var hasText = len > 0 && len <= max;
        btnGeneratePlay.disabled = !hasText || isGenerating;
        btnGenerateSave.disabled = !lastAudioBlob || isGenerating;
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
    cfgSlider.addEventListener('input', function() {
        cfgValue.textContent = parseFloat(cfgSlider.value).toFixed(1);
    });

    timestepsSlider.addEventListener('input', function() {
        timestepsValue.textContent = timestepsSlider.value;
    });

    maxLengthSlider.addEventListener('input', function() {
        maxLengthValue.textContent = maxLengthSlider.value;
    });

    btnRandomizeSeed.addEventListener('click', function() {
        seedInput.value = Math.floor(Math.random() * 999999);
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
            btnTextPlay.textContent = IS_CHINESE ? '生成中…' : 'Generating…';
            waveformIcon.style.opacity = '0.5';
        } else {
            btnIconPlay.textContent = '▶';
            btnTextPlay.textContent = _('generateAndPlay');
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
            }, 300);
        }, 3500);
    }

    // ── Create fresh blob URL for playback ──
    function createPlaybackURL(blob) {
        if (currentBlobURL) {
            try { URL.revokeObjectURL(currentBlobURL); } catch(e) {}
            currentBlobURL = null;
        }
        currentBlobURL = URL.createObjectURL(blob);
        return currentBlobURL;
    }

    // ── Ensure audio source is loaded and ready ──
    function ensureAudioReady(blob) {
        var url = currentBlobURL;
        if (!url && blob) {
            url = createPlaybackURL(blob);
        }
        if (url && audioPlayer.src !== url) {
            audioPlayer.src = url;
            audioPlayer.load();
        }
        return url;
    }

    // ── Show audio player ──
    function showPlayer(text, blob) {
        var displayText = text || '';
        if (displayText.length > 60) displayText = displayText.substring(0, 57) + '…';
        if (!displayText) displayText = _('generatedAudio');
        playerFilename.textContent = displayText;
        playerCard.classList.add('visible');
        lastAudioBlob = blob;
        lastText = text;

        btnGenerateSave.disabled = !lastAudioBlob || isGenerating;

        var url = createPlaybackURL(blob);
        audioPlayer.src = url;
        audioPlayer.load();

        audioPlayer.onloadedmetadata = function() {
            var dur = audioPlayer.duration;
            playerTimesInline.textContent = '00:00 / ' + formatTime(dur);
            playerProgress.max = Math.floor(dur * 100) || 100;
            playerProgress.value = 0;
        };

        audioPlayer.onended = function() {
            btnPlayPause.textContent = '▶';
            playerProgress.value = 0;
            playerTimesInline.textContent = '00:00 / ' + formatTime(audioPlayer.duration || 0);
        };
    }

    // ── Player: Play / Pause ──
    btnPlayPause.addEventListener('click', function() {
        if (!lastAudioBlob) return;
        if (audioPlayer.paused || audioPlayer.ended) {
            ensureAudioReady(lastAudioBlob);
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
            var cur = audioPlayer.currentTime;
            var dur = audioPlayer.duration;
            playerProgress.value = Math.floor(cur * 100);
            playerTimesInline.textContent = formatTime(cur) + ' / ' + formatTime(dur);
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
        var dur = audioPlayer.duration || 0;
        playerTimesInline.textContent = formatTime(seekTime) + ' / ' + formatTime(dur);
    });

    playerProgress.addEventListener('change', function() {
        playerSeeking = false;
        var seekTime = parseInt(playerProgress.value) / 100;
        if (audioPlayer.duration) {
            audioPlayer.currentTime = seekTime;
        }
    });

    // ── Player: Instant Replay ──
    btnReplay.addEventListener('click', function() {
        if (!lastAudioBlob) return;

        var url = createPlaybackURL(lastAudioBlob);
        audioPlayer.src = url;
        audioPlayer.load();

        audioPlayer.currentTime = 0;
        playerProgress.value = 0;
        playerTimesInline.textContent = '00:00 / ' + formatTime(audioPlayer.duration || 0);
        btnPlayPause.textContent = '⏸';

        var playPromise = audioPlayer.play();
        if (playPromise !== undefined) {
            playPromise.catch(function(e) {
                console.warn('[VoxBox] Replay play() rejected, waiting for canplay:', e.message);
                audioPlayer.oncanplay = function() {
                    audioPlayer.play().catch(function(e2) {
                        console.warn('[VoxBox] Replay fallback also failed:', e2.message);
                    });
                    audioPlayer.oncanplay = null;
                };
                audioPlayer.load();
            });
        }
    });

    // ── Core: call TTS API ──
    function callTTS(text) {
        var cfg = parseFloat(cfgSlider.value);
        var timesteps = parseInt(timestepsSlider.value);
        var voice = voiceSelect.value;
        var voiceMode = voiceModeSelect.value;

        if (voice && voice.indexOf('__preset__') === 0) {
            voice = '';
        }

        var body = {
            model: 'voxcpm2',
            input: text,
            cfg_value: cfg,
            inference_timesteps: timesteps,
            response_format: 'wav'
        };

        if (voice) {
            body.voice = voice;
            body.voice_mode = voiceMode;
        }

        var seed = parseInt(seedInput.value);
        if (seed >= 0) {
            body.seed = seed;
        }
        body.max_length = parseInt(maxLengthSlider.value);

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
        var url = createPlaybackURL(blob);
        audioPlayer.src = url;
        audioPlayer.load();
        audioPlayer.play().catch(function(e) {
            console.warn('[VoxBox] Audio playback failed:', e);
        });
    }

    // ── Generate & Play ──
    btnGeneratePlay.addEventListener('click', function() {
        if (isGenerating) return;

        var text = textInput.value.trim();
        if (!text || text.length > 2000) return;

        lastText = text;
        setGenerating(true);
        setStatus('generating', _('generating'));

        callTTS(text).then(function(blob) {
            lastAudioBlob = blob;
            setGenerating(false);
            setStatus('success', _('successPlay'));
            showPlayer(text, blob);
            playAudioBlob(blob);
        }).catch(function(err) {
            setGenerating(false);
            setStatus('error', _('errorPrefix') + err.message);
            console.error('[VoxBox] TTS error:', err);
        });
    });

    // ── Save Audio → triggers native NSSavePanel via bridge ──
    btnGenerateSave.addEventListener('click', function() {
        if (!lastAudioBlob) return;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.voxbox) {
            window.webkit.messageHandlers.voxbox.postMessage({type: 'saveAudio'});
        } else {
            var url = URL.createObjectURL(lastAudioBlob);
            var a = document.createElement('a');
            a.href = url;
            var fname = (lastText || 'voxbox_audio').replace(/[^a-zA-Z0-9 _-]/g, '').trim() || 'voxbox_audio';
            a.download = fname + '.wav';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
        }
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
    applyL10n();
    updateCharCount();
    textInput.focus();
    loadLocalPresets();
    loadVoices();

    console.log('[VoxBox] Native frontend ready · Port ' + SERVER_PORT + ' · ' + (IS_CHINESE ? '中文' : 'English'));
})();
</script>
</body>
</html>
"""

}

// MARK: - WebView

struct WebView: NSViewRepresentable {
    let port: Int
    /// (audioData, textUsed, voiceName)
    var onAudioCaptured: ((Data, String, String) -> Void)? = nil
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
        let isChinese = LocalizationManager.shared.isChinese
        let html = VoxBoxHTML.html(port: port, isChinese: isChinese)
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
            '<div style="display:flex;align-items:center;gap:8px;padding:8px 14px;' +
            'background:rgba(22,22,40,0.9);color:#e2e8f0;' +
            'border-radius:10px;font-size:13px;font-family:-apple-system,BlinkMacSystemFont,sans-serif;' +
            'box-shadow:0 4px 20px rgba(0,0,0,0.3);pointer-events:auto;max-width:460px;' +
            'border:1px solid rgba(255,255,255,0.07);line-height:1.5;">' +
            '<span style="white-space:nowrap;font-weight:600;">\(toastMsg)</span>' +
            '<span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#94a3b8;">· ' +
                escapeHTML(displayText) +
            '</span>' +
            '<button id="voxbox-notif-open" title="\(openLabel)" style="padding:3px 8px;background:rgba(255,255,255,0.08);color:#e2e8f0;border:1px solid rgba(255,255,255,0.1);' +
                'border-radius:6px;cursor:pointer;font-size:13px;line-height:1;transition:background 0.15s;">' +
                '\(openLabel)' +
            '</button>' +
            '<button id="voxbox-notif-close" style="padding:2px 4px;background:transparent;color:#94a3b8;' +
                'border:none;cursor:pointer;font-size:15px;line-height:1;transition:color 0.15s;">' +
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
            var voiceName = '';
            if (urlStr.indexOf('/audio/speech') !== -1) {
                try {
                    var options = arguments[1];
                    if (options && typeof options.body === 'string') {
                        var body = JSON.parse(options.body);
                        inputText = body.input || '';
                        voiceName = body.voice || '';
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
                                    text: inputText,
                                    voice: voiceName
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
        var onAudioCaptured: ((Data, String, String) -> Void)?
        var onSaveRequested: (() -> Void)?
        var onSaveHistoryItem: ((Int) -> Void)?
        var onOpenRecordingsFolder: (() -> Void)?
        var isLoading = false
        weak var webView: WKWebView?

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            self.webView = webView
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            self.webView = webView
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

        // MARK: - WKUIDelegate (enables JS alert / confirm in WKWebView)

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "VoxBox"
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            guard let window = webView.window else {
                completionHandler()
                return
            }
            alert.beginSheetModal(for: window) { _ in
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "VoxBox"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            guard let window = webView.window else {
                completionHandler(false)
                return
            }
            alert.beginSheetModal(for: window) { response in
                completionHandler(response == .alertFirstButtonReturn)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "voxbox":
                guard let body = message.body as? [String: Any],
                      let type = body["type"] as? String else { return }
                switch type {
                case "log":
                    if let msg = body["message"] as? String {
                        print("🌐 [WebView] \(msg)")
                    }
                case "saveAudio":
                    DispatchQueue.main.async { [weak self] in
                        self?.onSaveRequested?()
                    }
                case "saveAudioAtIndex":
                    if let idx = body["index"] as? Int {
                        DispatchQueue.main.async { [weak self] in
                            self?.onSaveHistoryItem?(idx)
                        }
                    }
                case "openRecordingsFolder":
                    DispatchQueue.main.async { [weak self] in
                        self?.onOpenRecordingsFolder?()
                    }
                case "pickAudioFile":
                    DispatchQueue.main.async { [weak self] in
                        self?.handlePickAudioFile()
                    }
                default:
                    break
                }

            case "audioCaptured":
                guard let body = message.body as? [String: Any],
                      let base64 = body["data"] as? String,
                      let audioData = Data(base64Encoded: base64) else {
                    print("⚠️ [VoxBox] Failed to decode captured audio")
                    return
                }
                let text = body["text"] as? String ?? ""
                let voice = body["voice"] as? String ?? ""
                print("🎵 [VoxBox] Audio captured: \(audioData.count) bytes, text: \"\(text.prefix(40))\"")
                DispatchQueue.main.async { [weak self] in
                    self?.onAudioCaptured?(audioData, text, voice)
                }

            default:
                break
            }
        }

        // MARK: - File Picker for Voice Creation

        private func handlePickAudioFile() {
            let panel = NSOpenPanel()
            panel.title = "Select Reference Audio"
            panel.message = "Choose a WAV, MP3, or FLAC file as voice reference"
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.wav, .mp3,UTType(filenameExtension: "ogg") ?? .audio, UTType(filenameExtension: "aac") ?? .audio]
            panel.canCreateDirectories = false
            panel.level = .modalPanel

            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else {
                    self?.sendAudioPathToJS("")
                    return
                }
                let path = url.path
                print("📁 [VoxBox] Audio file picked: \(path)")
                self?.sendAudioPathToJS(path)
            }
        }

        private func sendAudioPathToJS(_ path: String) {
            let escaped = path
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")

            let js = "if(window.__voxboxOnAudioFilePicked) window.__voxboxOnAudioFilePicked('\(escaped)');"
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(js) { _, error in
                    if let error = error {
                        print("⚠️ [VoxBox] Failed to send audio path to JS: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
