import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    /// (audioData, textUsed)
    var onAudioCaptured: ((Data, String) -> Void)? = nil
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.onAudioCaptured = onAudioCaptured
        
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        
        // ── VoxBox bridge (existing) ──
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
        
        // ── Audio capture bridge ──
        let audioCaptureScript = """
        (function() {
            if (typeof window.fetch !== 'function' || !window.webkit || !window.webkit.messageHandlers) return;
            
            var _fetch = window.fetch;
            window.fetch = function() {
                var url = arguments[0];
                var urlStr = '';
                if (typeof url === 'string') urlStr = url;
                else if (url instanceof Request) urlStr = url.url;
                else urlStr = String(url);
                
                // ── Extract text from request body ──
                var inputText = '';
                if (urlStr.indexOf('/audio/speech') !== -1) {
                    try {
                        var options = arguments[1];
                        if (options && typeof options.body === 'string') {
                            var body = JSON.parse(options.body);
                            inputText = body.input || '';
                        }
                    } catch(e) { /* ignore parse errors */ }
                }
                
                return _fetch.apply(this, arguments).then(function(response) {
                    if (urlStr.indexOf('/audio/speech') !== -1 && response.ok) {
                        var ct = response.headers.get('content-type') || '';
                        if (ct.indexOf('audio/') !== -1) {
                            var clone = response.clone();
                            clone.arrayBuffer().then(function(buffer) {
                                var base64 = _arrayBufferToBase64(buffer);
                                window.webkit.messageHandlers.audioCaptured.postMessage({
                                    data: base64,
                                    mimeType: ct,
                                    text: inputText
                                });
                            }).catch(function(e) {
                                console.log('[VoxBox] Audio capture error:', e);
                            });
                        }
                    }
                    return response;
                });
            };
            
            function _arrayBufferToBase64(buffer) {
                var bytes = new Uint8Array(buffer);
                var chunkSize = 8192;
                var chunks = [];
                for (var i = 0; i < bytes.length; i += chunkSize) {
                    chunks.push(String.fromCharCode.apply(null, bytes.subarray(i, i + chunkSize)));
                }
                return btoa(chunks.join(''));
            }
            
            console.log('[VoxBox] Audio capture bridge ready');
        })();
        """
        let audioCaptureUserScript = WKUserScript(source: audioCaptureScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(audioCaptureUserScript)
        userContentController.add(context.coordinator, name: "audioCaptured")
        
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Record the URL we're about to load so updateNSView doesn't double-fire
        context.coordinator.requestedURL = url
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAudioCaptured = onAudioCaptured
        
        // Only reload if the URL actually changed (prevents code 102: Frame load interrupted)
        guard url != context.coordinator.requestedURL else { return }
        context.coordinator.requestedURL = url
        
        // Also avoid reloading during an in-progress navigation
        guard !context.coordinator.isLoading else { return }
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        webView.load(request)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onAudioCaptured: ((Data, String) -> Void)?
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
            // code 102 = Frame load interrupted — typically from a double-load, not fatal
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
                print("⚠️ WebView load interrupted (likely double-load), retrying...")
                // Retry once if we haven't successfully loaded yet
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
