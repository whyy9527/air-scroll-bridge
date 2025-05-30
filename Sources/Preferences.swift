import Foundation
import ServiceManagement
import Combine

class Preferences: ObservableObject {
    // MARK: - Properties
    private let userDefaults: UserDefaults
    private let suiteName = "com.example.AirScrollBridge"
    
    // Keys
    private enum Keys {
        static let serverPort = "serverPort"
        static let launchAtLogin = "launchAtLogin"
    }
    
    // Default values
    private enum Defaults {
        static let serverPort = 17604
        static let launchAtLogin = false
    }
    
    // Published properties
    @Published var serverPort: Int {
        didSet {
            userDefaults.set(serverPort, forKey: Keys.serverPort)
            print("💾 Server port saved: \(serverPort)")
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            setLaunchAtLogin(enabled: launchAtLogin)
            print("💾 Launch at login saved: \(launchAtLogin)")
        }
    }
    
    // MARK: - Initialization
    init() {
        // Create user defaults with suite name
        userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        
        // Load saved preferences
        serverPort = userDefaults.object(forKey: Keys.serverPort) as? Int ?? Defaults.serverPort
        launchAtLogin = userDefaults.bool(forKey: Keys.launchAtLogin)
        
        print("📱 Preferences loaded - Port: \(serverPort), Launch at login: \(launchAtLogin)")
    }
    
    // MARK: - Validation
    func isValidPort(_ port: Int) -> Bool {
        return port >= 1024 && port <= 65535
    }
    
    func validateAndSetPort(_ port: Int) -> Bool {
        guard isValidPort(port) else {
            print("❌ Invalid port: \(port). Must be between 1024-65535")
            return false
        }
        
        serverPort = port
        return true
    }
    
    // MARK: - Launch at Login
    private func setLaunchAtLogin(enabled: Bool) {
        // Get the bundle identifier for the main app
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            print("❌ Could not get bundle identifier")
            return
        }
        
        let helperBundleId = "\(bundleIdentifier).LaunchHelper"
        
        if #available(macOS 13.0, *) {
            // Use modern SMAppService API for macOS 13+
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ Registered for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ Unregistered from launch at login")
                }
            } catch {
                print("❌ Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            let success = SMLoginItemSetEnabled(helperBundleId as CFString, enabled)
            if success {
                print("✅ \(enabled ? "Enabled" : "Disabled") launch at login")
            } else {
                print("❌ Failed to \(enabled ? "enable" : "disable") launch at login")
            }
        }
    }
    
    // MARK: - Reset
    func resetToDefaults() {
        serverPort = Defaults.serverPort
        launchAtLogin = Defaults.launchAtLogin
        print("🔄 Preferences reset to defaults")
    }
    
    // MARK: - Export/Import (for future use)
    func exportPreferences() -> [String: Any] {
        return [
            Keys.serverPort: serverPort,
            Keys.launchAtLogin: launchAtLogin
        ]
    }
    
    func importPreferences(_ data: [String: Any]) {
        if let port = data[Keys.serverPort] as? Int, isValidPort(port) {
            serverPort = port
        }
        
        if let launch = data[Keys.launchAtLogin] as? Bool {
            launchAtLogin = launch
        }
        
        print("📥 Preferences imported")
    }
}

// MARK: - Port Utilities
extension Preferences {
    /// Check if a port is available for binding
    static func isPortAvailable(_ port: Int) -> Bool {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFileDescriptor != -1 else {
            return false
        }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        close(socketFileDescriptor)
        return bindResult == 0
    }
    
    /// Get next available port starting from the given port
    static func getNextAvailablePort(startingFrom port: Int) -> Int? {
        for testPort in port..<65536 {
            if isPortAvailable(testPort) {
                return testPort
            }
        }
        return nil
    }
}
