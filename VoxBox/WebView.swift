import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    var onAudioCaptured: ((Data) -> Void)? = nil
    
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
                
                return _fetch.apply(this, arguments).then(function(response) {
                    if (urlStr.indexOf('/audio/speech') !== -1 && response.ok) {
                        var ct = response.headers.get('content-type') || '';
                        if (ct.indexOf('audio/') !== -1) {
                            var clone = response.clone();
                            clone.arrayBuffer().then(function(buffer) {
                                var base64 = _arrayBufferToBase64(buffer);
                                window.webkit.messageHandlers.audioCaptured.postMessage({
                                    data: base64,
                                    mimeType: ct
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
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onAudioCaptured = onAudioCaptured
        if webView.url != url {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onAudioCaptured: ((Data) -> Void)?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView loaded: \(webView.url?.absoluteString ?? "unknown")")
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed: \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
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
                }
                
            case "audioCaptured":
                guard let body = message.body as? [String: Any],
                      let base64 = body["data"] as? String,
                      let audioData = Data(base64Encoded: base64) else {
                    print("⚠️ [VoxBox] Failed to decode captured audio")
                    return
                }
                print("🎵 [VoxBox] Audio captured: \(audioData.count) bytes")
                DispatchQueue.main.async { [weak self] in
                    self?.onAudioCaptured?(audioData)
                }
                
            default:
                break
            }
        }
    }
}
