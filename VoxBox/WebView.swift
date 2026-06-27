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