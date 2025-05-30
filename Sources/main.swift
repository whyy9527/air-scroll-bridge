import Cocoa

// Check macOS version compatibility
if #available(macOS 14.0, *) {
    // Set up the NSApplication
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    
    // Run the application
    app.run()
} else {
    // Show compatibility warning for older macOS versions
    let alert = NSAlert()
    alert.messageText = "macOS Version Not Supported"
    alert.informativeText = "AirScrollBridge requires macOS 14.0 or later to access AirPods motion data. Please update your system."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Quit")
    
    alert.runModal()
    exit(1)
}
