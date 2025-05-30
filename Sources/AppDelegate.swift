import Cocoa
import CoreMotion
import Combine

@available(macOS 14.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var popoverViewController: PopoverViewController!
    private var motionManager: MotionManager?
    private var webSocketServer: WebSocketServer!
    private var preferences: Preferences!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApplication()
        setupStatusItem()
        setupPopover()
        setupManagers()
        setupBindings()
        requestMotionPermission()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        webSocketServer?.stop()
        motionManager?.stopMotionUpdates()
    }
    
    // MARK: - Setup
    private func setupApplication() {
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "AirScrollBridge")
            button.imagePosition = .imageOnly
            button.action = #selector(statusItemClicked)
            button.target = self
            updateStatusIcon(isConnected: false)
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.animates = true
        
        popoverViewController = PopoverViewController()
        popover.contentViewController = popoverViewController
    }
    
    private func setupManagers() {
        preferences = Preferences()
        motionManager = MotionManager()
        webSocketServer = WebSocketServer(port: preferences.serverPort)
    }
    
    private func setupBindings() {
        // Motion data binding
        motionManager?.motionDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] motionData in
                self?.popoverViewController.updateMotionData(motionData)
                self?.webSocketServer.broadcastMotionData(motionData)
            }
            .store(in: &cancellables)
        
        // WebSocket connection status binding
        webSocketServer.connectionCountPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.popoverViewController.updateConnectionCount(count)
                self?.updateStatusIcon(isConnected: count > 0)
            }
            .store(in: &cancellables)
        
        // Preferences binding
        preferences.$serverPort
            .dropFirst() // Skip initial value
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newPort in
                self?.restartWebSocketServer(port: newPort)
            }
            .store(in: &cancellables)
        
        // Pass preferences to popover
        popoverViewController.preferences = preferences
    }
    
    private func requestMotionPermission() {
        guard let motionManager = motionManager else {
            showMotionUnavailableAlert()
            return
        }
        
        motionManager.requestPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.startServices()
                } else {
                    self?.showPermissionAlert()
                }
            }
        }
    }
    
    private func startServices() {
        motionManager?.startMotionUpdates()
        webSocketServer.start()
    }
    
    private func restartWebSocketServer(port: Int) {
        webSocketServer.stop()
        webSocketServer = WebSocketServer(port: port)
        
        // Re-bind connection count publisher
        webSocketServer.connectionCountPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.popoverViewController.updateConnectionCount(count)
                self?.updateStatusIcon(isConnected: count > 0)
            }
            .store(in: &cancellables)
        
        webSocketServer.start()
    }
    
    // MARK: - UI Updates
    private func updateStatusIcon(isConnected: Bool) {
        DispatchQueue.main.async { [weak self] in
            if let button = self?.statusItem.button {
                button.image = NSImage(systemSymbolName: isConnected ? "circle.fill" : "circle", 
                                     accessibilityDescription: "AirScrollBridge")
                button.image?.isTemplate = true
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Motion Permission Required"
        alert.informativeText = "AirScrollBridge needs access to headphone motion data to function. Please grant permission in System Preferences > Privacy & Security > Motion & Fitness."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion")!)
        }
        NSApp.terminate(nil)
    }
    
    private func showMotionUnavailableAlert() {
        let alert = NSAlert()
        alert.messageText = "AirPods Motion Not Available"
        alert.informativeText = "This app requires macOS 14.0 or later to access AirPods motion data. Please update your system or use compatible hardware."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        
        alert.runModal()
        NSApp.terminate(nil)
    }
    
    // MARK: - Actions
    @objc private func statusItemClicked() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
