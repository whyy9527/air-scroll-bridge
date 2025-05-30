import CoreMotion
import Combine
import Foundation
import QuartzCore

/// Represents motion data from AirPods
struct MotionData: Codable {
    let pitch: Double  // in radians
    let yaw: Double    // in radians  
    let roll: Double   // in radians
    let timestamp: TimeInterval
    
    /// Convert to degrees for display
    var pitchDegrees: Double { pitch * 180.0 / .pi }
    var yawDegrees: Double { yaw * 180.0 / .pi }
    var rollDegrees: Double { roll * 180.0 / .pi }
}

@available(macOS 14.0, *)
class MotionManager: ObservableObject {
    // MARK: - Properties
    private let motionManager = CMHeadphoneMotionManager()
    private let motionQueue = OperationQueue()
    private var lastMotionTime: TimeInterval = 0
    private var isStationary = false
    private var stationaryTimer: Timer?
    
    // Motion update frequency (60 Hz)
    private let updateInterval: TimeInterval = 1.0 / 60.0
    // Stationary detection threshold (3 seconds)
    private let stationaryThreshold: TimeInterval = 3.0
    // Energy saving check interval (1 second)
    private let energySavingInterval: TimeInterval = 1.0
    
    // Publishers
    private let motionDataSubject = PassthroughSubject<MotionData, Never>()
    var motionDataPublisher: AnyPublisher<MotionData, Never> {
        motionDataSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        setupMotionQueue()
    }
    
    deinit {
        stopMotionUpdates()
    }
    
    // MARK: - Setup
    private func setupMotionQueue() {
        motionQueue.name = "com.airscrollbridge.motion"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInitiated
    }
    
    // MARK: - Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Device motion not available")
            completion(false)
            return
        }
        
        // Check if we already have permission by trying to start briefly
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            DispatchQueue.main.async {
                if error != nil {
                    print("❌ Motion permission denied: \(error?.localizedDescription ?? "Unknown error")")
                    completion(false)
                } else {
                    print("✅ Motion permission granted")
                    self?.motionManager.stopDeviceMotionUpdates()
                    completion(true)
                }
            }
        }
        
        // Stop after a brief moment to check permission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.motionManager.stopDeviceMotionUpdates()
        }
    }
    
    // MARK: - Motion Updates
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Device motion not available")
            return
        }
        
        // CMHeadphoneMotionManager doesn't have deviceMotionUpdateInterval
        // It uses its own update frequency
        
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            self?.handleMotionUpdate(motion: motion, error: error)
        }
        
        print("🎯 Started motion updates at \(Int(1/updateInterval)) Hz")
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        stationaryTimer?.invalidate()
        stationaryTimer = nil
        isStationary = false
        print("⏹️ Stopped motion updates")
    }
    
    // MARK: - Motion Processing
    private func handleMotionUpdate(motion: CMDeviceMotion?, error: Error?) {
        guard let motion = motion, error == nil else {
            if let error = error {
                print("❌ Motion update error: \(error.localizedDescription)")
            }
            return
        }
        
        let currentTime = CACurrentMediaTime()
        
        // Energy saving: detect stationary state
        if shouldEnterEnergySavingMode(motion: motion, currentTime: currentTime) {
            return
        }
        
        // Extract attitude data
        let attitude = motion.attitude
        let motionData = MotionData(
            pitch: attitude.pitch,
            yaw: attitude.yaw,
            roll: attitude.roll,
            timestamp: currentTime
        )
        
        lastMotionTime = currentTime
        isStationary = false
        
        // Publish motion data
        motionDataSubject.send(motionData)
    }
    
    private func shouldEnterEnergySavingMode(motion: CMDeviceMotion, currentTime: TimeInterval) -> Bool {
        // Check motion confidence for energy saving
        let isLowConfidence = motion.magneticField.accuracy == .uncalibrated || 
                             motion.attitude.pitch.isNaN || 
                             motion.attitude.yaw.isNaN || 
                             motion.attitude.roll.isNaN
        
        if isLowConfidence {
            if !isStationary {
                print("⚡ Entering energy saving mode (low confidence)")
                isStationary = true
                scheduleEnergySavingCheck()
            }
            return true
        }
        
        // Check for stationary state (no significant motion for 3 seconds)
        let timeSinceLastMotion = currentTime - lastMotionTime
        if timeSinceLastMotion > stationaryThreshold && !isStationary {
            print("⚡ Entering energy saving mode (stationary)")
            isStationary = true
            scheduleEnergySavingCheck()
            return true
        }
        
        return false
    }
    
    private func scheduleEnergySavingCheck() {
        stationaryTimer?.invalidate()
        stationaryTimer = Timer.scheduledTimer(withTimeInterval: energySavingInterval, repeats: false) { [weak self] _ in
            // Timer will naturally re-enable motion processing on next update
            self?.isStationary = false
        }
    }
}

// MARK: - Extensions
extension MotionData {
    /// JSON representation for WebSocket transmission
    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            print("❌ Failed to encode motion data: \(error)")
            return "{}"
        }
    }
}

extension MotionData: CustomStringConvertible {
    var description: String {
        return String(format: "Pitch: %.1f°, Yaw: %.1f°, Roll: %.1f°", 
                     pitchDegrees, yawDegrees, rollDegrees)
    }
}
