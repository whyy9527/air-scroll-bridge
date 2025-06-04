import Cocoa
import Combine

class PopoverViewController: NSViewController {
    // MARK: - Properties
    var preferences: Preferences?
    private var cancellables = Set<AnyCancellable>()
    
    // UI Elements
    private var motionDataLabel: NSTextField!
    private var connectionCountLabel: NSTextField!
    private var portTextField: NSTextField!
    private var savePortButton: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var statusIndicator: NSImageView!
    
    // Current motion data
    private var currentMotionData: MotionData?
    private var updateTimer: Timer?
    
    // MARK: - Lifecycle
    override func loadView() {
        setupProgrammaticView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        updateUIFromPreferences()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - UI Setup
    private func setupProgrammaticView() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        
        // Motion data label
        motionDataLabel = NSTextField(frame: NSRect(x: 20, y: 140, width: 260, height: 40))
        motionDataLabel.isEditable = false
        motionDataLabel.isBezeled = false
        motionDataLabel.drawsBackground = false
        motionDataLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        motionDataLabel.stringValue = "Waiting for motion data..."
        motionDataLabel.alignment = .center
        contentView.addSubview(motionDataLabel)
        
        // Connection status
        statusIndicator = NSImageView(frame: NSRect(x: 20, y: 110, width: 16, height: 16))
        statusIndicator.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Status")
        statusIndicator.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(statusIndicator)
        
        connectionCountLabel = NSTextField(frame: NSRect(x: 46, y: 108, width: 234, height: 20))
        connectionCountLabel.isEditable = false
        connectionCountLabel.isBezeled = false
        connectionCountLabel.drawsBackground = false
        connectionCountLabel.stringValue = "0 clients connected"
        contentView.addSubview(connectionCountLabel)
        
        // Port configuration
        let portLabel = NSTextField(frame: NSRect(x: 20, y: 75, width: 40, height: 20))
        portLabel.isEditable = false
        portLabel.isBezeled = false
        portLabel.drawsBackground = false
        portLabel.stringValue = "Port:"
        contentView.addSubview(portLabel)
        
        portTextField = NSTextField(frame: NSRect(x: 70, y: 75, width: 80, height: 20))
        portTextField.placeholderString = "17604"
        contentView.addSubview(portTextField)
        
        savePortButton = NSButton(frame: NSRect(x: 160, y: 73, width: 60, height: 24))
        savePortButton.title = "Save"
        savePortButton.bezelStyle = .rounded
        savePortButton.target = self
        savePortButton.action = #selector(savePortClicked)
        contentView.addSubview(savePortButton)
        
        // Launch at login checkbox
        launchAtLoginCheckbox = NSButton(frame: NSRect(x: 20, y: 45, width: 260, height: 20))
        launchAtLoginCheckbox.setButtonType(.switch)
        launchAtLoginCheckbox.title = "Launch at Login"
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginToggled)
        contentView.addSubview(launchAtLoginCheckbox)
        
        // Quit button
        let quitButton = NSButton(frame: NSRect(x: 20, y: 15, width: 60, height: 24))
        quitButton.title = "Quit"
        quitButton.bezelStyle = .rounded
        quitButton.target = self
        quitButton.action = #selector(quitClicked)
        contentView.addSubview(quitButton)
        
        self.view = contentView
    }
    

    private func setupUI() {
        // Update motion data every second (1 Hz display rate)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMotionDisplay()
        }
    }
    
    private func updateUIFromPreferences() {
        guard let preferences = preferences else { return }
        
        portTextField.stringValue = "\(preferences.serverPort)"
        launchAtLoginCheckbox.state = preferences.launchAtLogin ? .on : .off
    }
    
    // MARK: - Data Updates
    func updateMotionData(_ motionData: MotionData) {
        DispatchQueue.main.async { [weak self] in
            self?.currentMotionData = motionData
        }
    }
    
    func updateConnectionCount(_ count: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionCountLabel.stringValue = "\(count) client\(count == 1 ? "" : "s") connected"
            
            // Update status indicator
            let isConnected = count > 0
            self?.statusIndicator.image = NSImage(systemSymbolName: isConnected ? "circle.fill" : "circle", 
                                                accessibilityDescription: "Status")
            if isConnected {
                self?.statusIndicator.contentTintColor = .systemGreen
            } else {
                self?.statusIndicator.contentTintColor = .systemRed
            }
        }
    }
    
    private func updateMotionDisplay() {
        guard let motionData = currentMotionData else {
            motionDataLabel.stringValue = "Waiting for motion data..."
            return
        }
        
        let pitchStr = String(format: "%.1f°", motionData.pitchDegrees)
        let yawStr = String(format: "%.1f°", motionData.yawDegrees)
        let rollStr = String(format: "%.1f°", motionData.rollDegrees)
        
        motionDataLabel.stringValue = """
        Pitch: \(pitchStr)
        Yaw:   \(yawStr)
        Roll:  \(rollStr)
        """
    }
    
    // MARK: - Actions
    @objc private func savePortClicked() {
        guard let preferences = preferences else { return }
        guard let portText = portTextField.stringValue.isEmpty ? nil : portTextField.stringValue,
              let port = Int(portText) else {
            showAlert(title: "Invalid Port", message: "Please enter a valid port number (1024-65535)")
            return
        }
        
        if !preferences.validateAndSetPort(port) {
            showAlert(title: "Invalid Port", message: "Port must be between 1024 and 65535")
            return
        }
        
        // Check if port is available
        if !Preferences.isPortAvailable(port) {
            let alert = NSAlert()
            alert.messageText = "Port Not Available"
            alert.informativeText = "Port \(port) is already in use. Would you like to use the next available port?"
            alert.addButton(withTitle: "Find Next Port")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let nextPort = Preferences.getNextAvailablePort(startingFrom: port) {
                    preferences.serverPort = nextPort
                    portTextField.stringValue = "\(nextPort)"
                    showAlert(title: "Port Updated", message: "Using port \(nextPort) instead")
                } else {
                    showAlert(title: "No Available Ports", message: "Could not find an available port")
                }
            }
            return
        }
        
        showAlert(title: "Port Saved", message: "Server will restart on port \(port)")
    }
    
    @objc private func launchAtLoginToggled() {
        guard let preferences = preferences else { return }
        preferences.launchAtLogin = (launchAtLoginCheckbox.state == .on)
    }
    
    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Utilities
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
