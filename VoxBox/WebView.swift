import SwiftUI
import WebKit

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
