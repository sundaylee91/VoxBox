import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    /// (audioData, textUsed)
    var onAudioCaptured: ((Data, String) -> Void)? = nil
    /// User clicked save in the in-page notification
    var onSaveRequested: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.onAudioCaptured = onAudioCaptured
        context.coordinator.onSaveRequested = onSaveRequested

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

        // ── Audio capture + notification bar ──
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
        guard url != context.coordinator.requestedURL else { return }
        context.coordinator.requestedURL = url
        guard !context.coordinator.isLoading else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        webView.load(request)
    }

    // MARK: - JS Injection

    private func createCaptureScript() -> String {
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

    // ── Floating notification bar ──
    function showNotification(text) {
        // Remove existing notification
        var existing = document.getElementById('voxbox-notification');
        if (existing) existing.remove();

        var displayText = text || 'Audio generated';
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
            '<button id="voxbox-save-btn" style="padding:6px 14px;background:#3b82f6;color:white;border:none;' +
                'border-radius:8px;cursor:pointer;font-size:12px;font-weight:600;white-space:nowrap;' +
                'transition:background 0.15s;">' +
                '💾 Save' +
            '</button>' +
            '<button id="voxbox-close-btn" style="padding:4px 6px;background:transparent;color:#94a3b8;' +
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

        // Inject keyframes once
        if (!document.getElementById('voxbox-keyframes')) {
            var style = document.createElement('style');
            style.id = 'voxbox-keyframes';
            style.textContent = [
                '@keyframes voxboxSlideIn{',
                'from{transform:translateX(120%);opacity:0}',
                'to{transform:translateX(0);opacity:1}',
                '}',
                '@keyframes voxboxSlideOut{',
                'from{transform:translateX(0);opacity:1}',
                'to{transform:translateX(120%);opacity:0}',
                '}'
            ].join('');
            document.head.appendChild(style);
        }

        // Wire buttons
        var saveBtn = document.getElementById('voxbox-save-btn');
        var closeBtn = document.getElementById('voxbox-close-btn');

        saveBtn.onmouseenter = function() { saveBtn.style.background = '#2563eb'; };
        saveBtn.onmouseleave = function() { saveBtn.style.background = '#3b82f6'; };
        saveBtn.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.voxbox) {
                window.webkit.messageHandlers.voxbox.postMessage({type: 'saveAudio'});
            }
            // Briefly pulse button
            saveBtn.textContent = '✅ Saved!';
            saveBtn.style.background = '#22c55e';
            setTimeout(function() {
                saveBtn.textContent = '💾 Save';
                saveBtn.style.background = '#3b82f6';
            }, 1500);
        };

        closeBtn.onmouseenter = function() { closeBtn.style.color = '#e2e8f0'; };
        closeBtn.onmouseleave = function() { closeBtn.style.color = '#94a3b8'; };
        closeBtn.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            dismissNotification(notif);
        };

        // Auto-dismiss after 30 seconds
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

    // ── Fetch hook - capture /v1/audio/speech responses ──
    if (typeof window.fetch === 'function') {
        var _fetch = window.fetch;
        window.fetch = function() {
            var url = arguments[0];
            var urlStr = '';
            if (typeof url === 'string') urlStr = url;
            else if (url instanceof Request) urlStr = url.url;
            else urlStr = String(url);

            // Extract text from request body
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

    console.log('[VoxBox] Capture bridge ready');
})();
"""
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onAudioCaptured: ((Data, String) -> Void)?
        var onSaveRequested: (() -> Void)?
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
