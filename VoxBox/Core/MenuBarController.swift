import SwiftUI
import AppKit

final class MenuBarController: NSObject, ObservableObject {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private var eventMonitor: Any?
    
    // MARK: - Setup
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🔊"
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "VoxBox"
        }
        
        popover.contentSize = NSSize(width: AppDelegate.defaultWindowSize.width,
                                      height: AppDelegate.defaultWindowSize.height)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(ServerManager.shared)
        )
        
        // Monitor for clicks outside popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover()
        }
        
        buildMenu()
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }
    
    private func closePopover() {
        popover.performClose(nil)
    }
    
    // MARK: - Menu Bar Menu
    
    private func buildMenu() {
        let menu = NSMenu()
        
        // Show/Hide
        let showItem = NSMenuItem(title: "Show VoxBox", action: #selector(togglePopover), keyEquivalent: "v")
        showItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(showItem)
        
        menu.addItem(.separator())
        
        // Save Audio
        let saveItem = NSMenuItem(title: "💾 Save Audio…", action: #selector(saveAudioAction), keyEquivalent: "s")
        saveItem.keyEquivalentModifierMask = [.command, .shift]
        saveItem.target = self
        menu.addItem(saveItem)
        
        menu.addItem(.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit VoxBox", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func saveAudioAction() {
        ServerManager.shared.saveAudioWithPanel()
    }
    
    @objc private func quitAction() {
        ServerManager.shared.stop()
        NSApp.terminate(nil)
    }
    
    // MARK: - Update Menu State
    
    func updateMenuForStatus(_ status: ServerManager.Status) {
        guard let menu = statusItem?.menu else { return }
        
        // Update save item availability
        if let saveItem = menu.items.first(where: { $0.action == #selector(saveAudioAction) }) {
            switch status {
            case .running:
                saveItem.isEnabled = ServerManager.shared.lastAudioData != nil
            default:
                saveItem.isEnabled = false
            }
        }
    }
}
