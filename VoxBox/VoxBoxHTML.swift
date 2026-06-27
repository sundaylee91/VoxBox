import Foundation

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
        max-width: 560px;
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
        max-height: 200px;
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
    var btnGeneratePlay = document.getElementById('btn-generate-play');
    var btnGenerateSave = document.getElementById('btn-generate-save');
    var btnIconPlay = document.getElementById('btn-icon-play');
    var btnTextPlay = document.getElementById('btn-text-play');
    var statusEl = document.getElementById('status');
    var audioPlayer = document.getElementById('audio-player');
    var waveformIcon = document.getElementById('waveform-icon');

    // ── State ──
    var isGenerating = false;
    var lastAudioBlob = null;
    var lastText = '';

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

    // ── Speed slider ──
    speedSlider.addEventListener('input', function() {
        var val = parseFloat(speedSlider.value);
        speedValue.textContent = val.toFixed(1) + 'x';
    });

    // ── Sample rate slider ──
    sampleRateSlider.addEventListener('input', function() {
        var val = parseInt(sampleRateSlider.value);
        sampleRateValue.textContent = (val / 1000).toFixed(0) + ' kHz';
    });

    // ── Helpers ──
    function setStatus(state, message) {
        statusEl.className = 'status ' + state;
        statusEl.textContent = message;
    }

    function setGenerating(generating) {
        isGenerating = generating;
        updateCharCount(); // re-evaluate button states

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

    // ── Core: call TTS API ──
    function callTTS(text) {
        var speed = parseFloat(speedSlider.value);
        var sampleRate = parseInt(sampleRateSlider.value);

        var body = {
            input: text,
            speed: speed,
            sample_rate: sampleRate
        };

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
        // Clean up old blob URL after playback
        audioPlayer.onended = function() {
            URL.revokeObjectURL(url);
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

            // The native fetch hook will auto-save this audio.
            // Show a toast to confirm.
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

    // ── Pause waveform animation when generating ──
    // (handled in setGenerating via opacity change)

    console.log('[VoxBox] Native frontend ready · Port ' + SERVER_PORT);
})();
</script>
</body>
</html>
"""
}
