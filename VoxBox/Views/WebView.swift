import SwiftUI
import WebKit

#if canImport(AppKit)
import AppKit
#endif

// MARK: - WebView Representable

struct WebView: NSViewRepresentable {
    let url: URL
    let onAudioCaptured: ((Data, String) -> Void)?
    let onSaveRequested: (() -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onAudioCaptured: onAudioCaptured, onSaveRequested: onSaveRequested)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Inject audio capture script at document start
        let jsScript = createAudioCaptureScript()
        let userScript = WKUserScript(
            source: jsScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)
        
        // Register message handlers
        config.userContentController.add(context.coordinator, name: "audioCaptured")
        config.userContentController.add(context.coordinator, name: "saveAudio")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        
        context.coordinator.webView = webView
        context.coordinator.requestedURL = url
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Avoid reloading if already loading the same URL
        if context.coordinator.requestedURL != url && !context.coordinator.isLoading {
            context.coordinator.requestedURL = url
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
    
    // MARK: - JavaScript Injection
    
    private func createAudioCaptureScript() -> String {
        return """
(function() {
    'use strict';
    
    // Store latest audio data
    window.__voxboxAudio = null;
    window.__voxboxText = '';
    window.__voxboxDownloadBtn = null;
    
    // Helper: ArrayBuffer to Base64 (chunked for performance)
    function arrayBufferToBase64(buffer) {
        var bytes = new Uint8Array(buffer);
        var chunkSize = 0x8000; // 32KB chunks
        var chunks = [];
        for (var i = 0; i < bytes.length; i += chunkSize) {
            var chunk = bytes.subarray(i, i + chunkSize);
            chunks.push(String.fromCharCode.apply(null, chunk));
        }
        return btoa(chunks.join(''));
    }
    
    // Hook fetch to capture audio responses
    var originalFetch = window.fetch;
    window.fetch = function() {
        var args = arguments;
        var url = typeof args[0] === 'string' ? args[0] : (args[0] && args[0].url ? args[0].url : '');
        
        return originalFetch.apply(this, args).then(function(response) {
            if (url.indexOf('/audio/speech') !== -1 && response.ok) {
                // Try to get request body for text
                var requestText = '';
                if (args[1] && args[1].body) {
                    try {
                        var body = JSON.parse(args[1].body);
                        requestText = body.input || '';
                    } catch(e) {}
                }
                
                // Clone and capture audio
                var cloned = response.clone();
                cloned.arrayBuffer().then(function(buffer) {
                    var base64 = arrayBufferToBase64(buffer);
                    window.__voxboxAudio = base64;
                    window.__voxboxText = requestText;
                    
                    // Notify Swift
                    try {
                        window.webkit.messageHandlers.audioCaptured.postMessage({
                            data: base64,
                            text: requestText
                        });
                    } catch(e) {
                        console.log('[VoxBox] audioCaptured error:', e);
                    }
                    
                    // Enable download button
                    updateDownloadButton(true);
                }).catch(function(err) {
                    console.log('[VoxBox] arrayBuffer error:', err);
                });
            }
            return response;
        });
    };
    
    // Watch for audio elements and add download buttons
    function findAndDecorateAudioElements() {
        var audios = document.querySelectorAll('audio');
        audios.forEach(function(audio) {
            if (!audio.dataset.voxboxButtonAdded) {
                addDownloadButton(audio);
                audio.dataset.voxboxButtonAdded = '1';
            }
        });
    }
    
    function addDownloadButton(audioElement) {
        var container = audioElement.parentElement;
        if (!container) return;
        
        // Make container position relative if not already
        var containerStyle = window.getComputedStyle(container);
        if (containerStyle.position === 'static') {
            container.style.position = 'relative';
        }
        
        // Create download button
        var btn = document.createElement('button');
        btn.innerHTML = '⬇';
        btn.title = 'Save audio to Mac';
        btn.id = 'voxbox-download-btn';
        btn.style.cssText = [
            'display:inline-flex',
            'align-items:center',
            'justify-content:center',
            'width:32px',
            'height:32px',
            'margin-left:8px',
            'padding:0',
            'border:1px solid #d1d5db',
            'border-radius:8px',
            'background:#ffffff',
            'cursor:pointer',
            'font-size:16px',
            'line-height:1',
            'transition:all 0.2s ease',
            'vertical-align:middle',
            'box-shadow:0 1px 2px rgba(0,0,0,0.05)'
        ].join(';');
        
        btn.onmouseenter = function() {
            btn.style.background = '#f3f4f6';
            btn.style.borderColor = '#9ca3af';
        };
        btn.onmouseleave = function() {
            btn.style.background = '#ffffff';
            btn.style.borderColor = '#d1d5db';
        };
        btn.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            triggerSave();
            return false;
        };
        
        // Insert button after audio element
        audioElement.insertAdjacentElement('afterend', btn);
        window.__voxboxDownloadBtn = btn;
        
        // Set initial state
        updateDownloadButton(!!window.__voxboxAudio);
    }
    
    function updateDownloadButton(hasAudio) {
        var btn = window.__voxboxDownloadBtn;
        if (!btn) return;
        
        if (hasAudio) {
            btn.style.opacity = '1';
            btn.style.cursor = 'pointer';
            btn.title = 'Save audio to Mac';
            btn.style.color = '#374151';
        } else {
            btn.style.opacity = '0.4';
            btn.style.cursor = 'default';
            btn.title = 'Generate audio first';
            btn.style.color = '#9ca3af';
        }
    }
    
    function triggerSave() {
        if (!window.__voxboxAudio) return;
        
        try {
            window.webkit.messageHandlers.saveAudio.postMessage({
                data: window.__voxboxAudio,
                text: window.__voxboxText
            });
        } catch(e) {
            console.log('[VoxBox] saveAudio error:', e);
        }
    }
    
    // Observe DOM for new audio elements
    var observer = new MutationObserver(function() {
        findAndDecorateAudioElements();
    });
    
    // Start observing when DOM is ready
    function startObserving() {
        observer.observe(document.body || document.documentElement, {
            childList: true,
            subtree: true
        });
        findAndDecorateAudioElements();
    }
    
    if (document.body) {
        startObserving();
    } else {
        document.addEventListener('DOMContentLoaded', startObserving);
    }
    
    // Also try on load as fallback
    window.addEventListener('load', function() {
        findAndDecorateAudioElements();
    });
})();
"""
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onAudioCaptured: ((Data, String) -> Void)?
        let onSaveRequested: (() -> Void)?
        weak var webView: WKWebView?
        var requestedURL: URL?
        var isLoading = false
        private var loadRetryCount = 0
        
        init(onAudioCaptured: ((Data, String) -> Void)?, onSaveRequested: (() -> Void)?) {
            self.onAudioCaptured = onAudioCaptured
            self.onSaveRequested = onSaveRequested
        }
        
        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "audioCaptured")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "saveAudio")
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "audioCaptured" {
                handleAudioCaptured(message.body)
            } else if message.name == "saveAudio" {
                handleSaveRequest(message.body)
            }
        }
        
        private func handleAudioCaptured(_ body: Any) {
            guard let dict = body as? [String: Any],
                  let base64 = dict["data"] as? String else { return }
            
            let text = dict["text"] as? String ?? ""
            
            // Decode base64 on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let data = Data(base64Encoded: base64) else { return }
                DispatchQueue.main.async {
                    self?.onAudioCaptured?(data, text)
                }
            }
        }
        
        private func handleSaveRequest(_ body: Any) {
            DispatchQueue.main.async { [weak self] in
                self?.onSaveRequested?()
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            loadRetryCount = 0
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            let nsError = error as NSError
            print("⚠️ WebView provisional load failed: \(error.localizedDescription)")
            
            // Code 102 = Frame load interrupted (often from double-load)
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 && loadRetryCount < 2 {
                loadRetryCount += 1
                print("🔄 Retrying load (attempt \(loadRetryCount))...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, let url = self.requestedURL else { return }
                    let request = URLRequest(url: url)
                    self.webView?.load(request)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            print("⚠️ WebView navigation failed: \(error.localizedDescription)")
        }
    }
}
