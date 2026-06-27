import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    /// (audioData, textUsed)
    var onAudioCaptured: ((Data, String) -> Void)? = nil
    /// User clicked save in the in-page notification or history panel (index into audioHistory)
    var onSaveRequested: (() -> Void)? = nil
    /// User clicked save for a specific history item
    var onSaveHistoryItem: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.onAudioCaptured = onAudioCaptured
        context.coordinator.onSaveRequested = onSaveRequested
        context.coordinator.onSaveHistoryItem = onSaveHistoryItem

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
            getStatus: function() { return '\(url.absoluteString)'; },
            log: function(msg) { window.webkit.messageHandlers.voxbox.postMessage({type: 'log', message: msg}); }
        };
        """
        let bridgeUserScript = WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(bridgeUserScript)
        userContentController.add(context.coordinator, name: "voxbox")

        // ── Audio capture + notification + persistent download button ──
        let captureScript = createCaptureScript()
        let captureUserScript = WKUserScript(source: captureScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(captureUserScript)
        userContentController.add(context.coordinator, name: "audioCaptured")

        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.requestedURL = url
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        webView.load(request)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAudioCaptured = onAudioCaptured
        context.coordinator.onSaveRequested = onSaveRequested
        context.coordinator.onSaveHistoryItem = onSaveHistoryItem
        guard url != context.coordinator.requestedURL else { return }
        context.coordinator.requestedURL = url
        guard !context.coordinator.isLoading else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        webView.load(request)
    }

    // MARK: - JS Injection

    private func createCaptureScript() -> String {
        // Read language for JS strings
        let zh = LocalizationManager.shared.isChinese
        let jsSave = zh ? "💾 保存" : "💾 Save"
        let jsSaved = zh ? "✅ 已保存!" : "✅ Saved!"
        let jsHistory = zh ? "📥 历史" : "📥 History"
        let jsNoAudio = zh ? "暂无音频" : "No audio yet"
        let jsNotificationTitle = zh ? "🎵 音频已生成" : "🎵 Audio generated"

        return """
(function() {
    'use strict';
    if (window.__voxboxInjected) return;
    window.__voxboxInjected = true;

    // ── Local audio cache (JS side) ──
    var audioCache = []; // {data: base64, mimeType: string, text: string, time: Date}
    var MAX_CACHE = 50;

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

    function timeAgo(date) {
        var secs = Math.floor((new Date() - date) / 1000);
        if (secs < 60) return 'just now';
        if (secs < 3600) return Math.floor(secs/60) + 'm ago';
        return Math.floor(secs/3600) + 'h ago';
    }

    // ── Inject keyframes once ──
    function injectStyles() {
        if (document.getElementById('voxbox-styles')) return;
        var style = document.createElement('style');
        style.id = 'voxbox-styles';
        style.textContent = [
            '@keyframes voxboxSlideIn{from{transform:translateX(120%);opacity:0}to{transform:translateX(0);opacity:1}}',
            '@keyframes voxboxSlideOut{from{transform:translateX(0);opacity:1}to{transform:translateX(120%);opacity:0}}',
            '@keyframes voxboxFadeIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}',
            '#voxbox-history-btn:hover{transform:scale(1.08);box-shadow:0 4px 16px rgba(0,0,0,0.3)}',
            '#voxbox-history-panel{animation:voxboxFadeIn 0.25s ease-out}',
            '.voxbox-history-item:hover{background:rgba(255,255,255,0.06)}'
        ].join('');
        document.head.appendChild(style);
    }

    // ── Floating notification bar (top-right, auto-dismiss) ──
    function showNotification(text) {
        var existing = document.getElementById('voxbox-notification');
        if (existing) existing.remove();

        var displayText = text || '\(jsNotificationTitle)';
        if (displayText.length > 50) displayText = displayText.substring(0, 47) + '...';

        var notif = document.createElement('div');
        notif.id = 'voxbox-notification';
        notif.innerHTML =
            '<div style="display:flex;align-items:center;gap:10px;padding:10px 16px;' +
            'background:linear-gradient(135deg,#1e1e2e,#2a2a3e);color:#e2e8f0;' +
            'border-radius:12px;font-size:13px;font-family:-apple-system,BlinkMacSystemFont,sans-serif;' +
            'box-shadow:0 8px 32px rgba(0,0,0,0.35);pointer-events:auto;max-width:460px;' +
            'border:1px solid rgba(255,255,255,0.08);">' +
            '<span style="font-size:18px;">🎵</span>' +
            '<span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-weight:500;">' +
                escapeHTML(displayText) +
            '</span>' +
            '<button id="voxbox-notif-save" style="padding:6px 14px;background:#3b82f6;color:white;border:none;' +
                'border-radius:8px;cursor:pointer;font-size:12px;font-weight:600;white-space:nowrap;' +
                'transition:background 0.15s;">' +
                '\(jsSave)' +
            '</button>' +
            '<button id="voxbox-notif-close" style="padding:4px 6px;background:transparent;color:#94a3b8;' +
                'border:none;cursor:pointer;font-size:16px;line-height:1;transition:color 0.15s;">' +
                '✕' +
            '</button>' +
            '</div>';

        notif.style.cssText = [
            'position:fixed',
            'top:16px',
            'right:16px',
            'z-index:2147483647',
            'pointer-events:none',
            'animation:voxboxSlideIn 0.35s cubic-bezier(0.16,1,0.3,1)'
        ].join(';');

        document.body.appendChild(notif);
        injectStyles();

        var saveBtn = document.getElementById('voxbox-notif-save');
        var closeBtn = document.getElementById('voxbox-notif-close');

        saveBtn.onmouseenter = function() { saveBtn.style.background = '#2563eb'; };
        saveBtn.onmouseleave = function() { saveBtn.style.background = '#3b82f6'; };
        saveBtn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            saveLatestToSwift();
            saveBtn.textContent = '\(jsSaved)';
            saveBtn.style.background = '#22c55e';
            setTimeout(function() {
                saveBtn.textContent = '\(jsSave)';
                saveBtn.style.background = '#3b82f6';
            }, 1500);
        };

        closeBtn.onmouseenter = function() { closeBtn.style.color = '#e2e8f0'; };
        closeBtn.onmouseleave = function() { closeBtn.style.color = '#94a3b8'; };
        closeBtn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            dismissNotification(notif);
        };

        var timer = setTimeout(function() { dismissNotification(notif); }, 30000);
        notif._voxboxTimer = timer;
    }

    function dismissNotification(notif) {
        if (!notif || notif._voxboxDismissed) return;
        notif._voxboxDismissed = true;
        clearTimeout(notif._voxboxTimer);
        notif.style.animation = 'voxboxSlideOut 0.3s cubic-bezier(0.16,1,0.3,1) forwards';
        setTimeout(function() {
            if (notif.parentNode) notif.parentNode.removeChild(notif);
        }, 350);
    }

    // ── Persistent download history button (bottom-right) ──
    function ensureHistoryButton() {
        if (document.getElementById('voxbox-history-btn')) return;
        injectStyles();

        var btn = document.createElement('button');
        btn.id = 'voxbox-history-btn';
        btn.innerHTML = '\(jsHistory)';
        btn.style.cssText = [
            'position:fixed',
            'bottom:20px',
            'right:20px',
            'z-index:2147483646',
            'padding:8px 16px',
            'background:rgba(30,30,46,0.9)',
            'color:#e2e8f0',
            'border:1px solid rgba(255,255,255,0.12)',
            'border-radius:20px',
            'cursor:pointer',
            'font-size:13px',
            'font-family:-apple-system,BlinkMacSystemFont,sans-serif',
            'font-weight:500',
            'backdrop-filter:blur(12px)',
            '-webkit-backdrop-filter:blur(12px)',
            'transition:transform 0.2s,box-shadow 0.2s',
            'box-shadow:0 2px 12px rgba(0,0,0,0.25)'
        ].join(';');

        btn.onclick = function(e) {
            e.preventDefault(); e.stopPropagation();
            toggleHistoryPanel();
        };

        document.body.appendChild(btn);
        updateHistoryBadge();
    }

    function updateHistoryBadge() {
        var btn = document.getElementById('voxbox-history-btn');
        if (!btn) return;
        var count = audioCache.length;
        if (count > 0) {
            btn.innerHTML = '\(jsHistory) (' + count + ')';
        } else {
            btn.innerHTML = '\(jsHistory)';
        }
    }

    function toggleHistoryPanel() {
        var panel = document.getElementById('voxbox-history-panel');
        if (panel) {
            panel.remove();
            return;
        }
        showHistoryPanel();
    }

    function showHistoryPanel() {
        // Remove existing
        var existing = document.getElementById('voxbox-history-panel');
        if (existing) existing.remove();

        var panel = document.createElement('div');
        panel.id = 'voxbox-history-panel';

        var itemsHTML = '';
        if (audioCache.length === 0) {
            itemsHTML = '<div style="padding:20px;text-align:center;color:#94a3b8;font-size:13px;">\(jsNoAudio)</div>';
        } else {
            // Show newest first
            for (var i = audioCache.length - 1; i >= 0; i--) {
                var clip = audioCache[i];
                var label = clip.text || 'Untitled';
                if (label.length > 40) label = label.substring(0, 37) + '...';
                var ago = timeAgo(new Date(clip.time));
                itemsHTML +=
                    '<div class="voxbox-history-item" style="display:flex;align-items:center;gap:8px;padding:10px 14px;' +
                    'border-bottom:1px solid rgba(255,255,255,0.05);cursor:default;transition:background 0.15s;">' +
                    '<span style="font-size:14px;">🎵</span>' +
                    '<span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;color:#e2e8f0;">' +
                        escapeHTML(label) +
                    '</span>' +
                    '<span style="font-size:10px;color:#64748b;white-space:nowrap;">' + ago + '</span>' +
                    '<button data-idx="' + i + '" class="voxbox-save-item" style="padding:4px 10px;background:#3b82f6;color:white;border:none;' +
                        'border-radius:6px;cursor:pointer;font-size:11px;font-weight:600;white-space:nowrap;">' +
                        '\(jsSave)' +
                    '</button>' +
                    '</div>';
            }
        }

        panel.innerHTML =
            '<div style="background:rgba(22,22,36,0.96);border:1px solid rgba(255,255,255,0.1);border-radius:14px;' +
            'overflow:hidden;box-shadow:0 12px 40px rgba(0,0,0,0.5);backdrop-filter:blur(16px);' +
            '-webkit-backdrop-filter:blur(16px);max-height:360px;display:flex;flex-direction:column;">' +
            '<div style="display:flex;align-items:center;justify-content:space-between;padding:10px 14px;' +
            'border-bottom:1px solid rgba(255,255,255,0.08);">' +
            '<span style="font-size:13px;font-weight:600;color:#e2e8f0;">' + escapeHTML('\(jsHistory)') + '</span>' +
            '<button id="voxbox-panel-close" style="background:transparent;border:none;color:#94a3b8;' +
            'cursor:pointer;font-size:16px;line-height:1;">✕</button>' +
            '</div>' +
            '<div style="overflow-y:auto;flex:1;">' +
                itemsHTML +
            '</div>' +
            '</div>';

        panel.style.cssText = [
            'position:fixed',
            'bottom:60px',
            'right:20px',
            'z-index:2147483647',
            'width:340px',
            'font-family:-apple-system,BlinkMacSystemFont,sans-serif'
        ].join(';');

        document.body.appendChild(panel);

        // Wire close button
        var closeBtn = document.getElementById('voxbox-panel-close');
        if (closeBtn) {
            closeBtn.onclick = function(e) {
                e.preventDefault(); e.stopPropagation();
                panel.remove();
            };
        }

        // Wire save buttons
        var saveButtons = panel.querySelectorAll('.voxbox-save-item');
        saveButtons.forEach(function(btn) {
            btn.onclick = function(e) {
                e.preventDefault(); e.stopPropagation();
                var idx = parseInt(this.getAttribute('data-idx'));
                saveHistoryItemToSwift(idx);
                this.textContent = '\(jsSaved)';
                this.style.background = '#22c55e';
                setTimeout(function() {
                    btn.textContent = '\(jsSave)';
                    btn.style.background = '#3b82f6';
                }, 1500);
            };
        });
    }

    // ── Send to Swift ──
    function saveLatestToSwift() {
        if (audioCache.length === 0) return;
        var idx = audioCache.length - 1;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.voxbox) {
            window.webkit.messageHandlers.voxbox.postMessage({type: 'saveAudio'});
        }
    }

    function saveHistoryItemToSwift(idx) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.voxbox) {
            window.webkit.messageHandlers.voxbox.postMessage({type: 'saveAudioAtIndex', index: idx});
        }
    }

    // ── Add audio to cache ──
    function addToCache(base64, mimeType, text) {
        audioCache.push({
            data: base64,
            mimeType: mimeType,
            text: text,
            time: new Date().toISOString()
        });
        if (audioCache.length > MAX_CACHE) {
            audioCache.shift();
        }
        updateHistoryBadge();
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

                            // Send to Swift
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.audioCaptured) {
                                window.webkit.messageHandlers.audioCaptured.postMessage({
                                    data: base64,
                                    mimeType: ct,
                                    text: inputText
                                });
                            }

                            // Add to local cache
                            addToCache(base64, ct, inputText);

                            // Show floating notification
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

    // ── Init ──
    ensureHistoryButton();

    // Re-ensure button on DOM changes (some SPAs replace body content)
    var observer = new MutationObserver(function() {
        if (!document.getElementById('voxbox-history-btn')) {
            ensureHistoryButton();
        }
    });
    if (document.body) {
        observer.observe(document.body, { childList: true, subtree: true });
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            ensureHistoryButton();
            observer.observe(document.body, { childList: true, subtree: true });
        });
    }

    console.log('[VoxBox] Capture bridge ready (with history panel)');
})();
"""
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onAudioCaptured: ((Data, String) -> Void)?
        var onSaveRequested: (() -> Void)?
        var onSaveHistoryItem: ((Int) -> Void)?
        var requestedURL: URL?
        var isLoading = false

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            print("✅ WebView loaded: \(webView.url?.absoluteString ?? "unknown")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            print("❌ WebView failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            let nsError = error as NSError
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
                print("⚠️ WebView load interrupted (likely double-load), retrying...")
                if webView.url == nil, let url = requestedURL {
                    let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
                    webView.load(request)
                }
            } else {
                print("⚠️ WebView provisional load failed: \(error.localizedDescription)")
            }
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
