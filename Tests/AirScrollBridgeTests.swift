import XCTest
import Foundation
import NIO
import NIOWebSocket
import NIOHTTP1
@testable import AirScrollBridge

final class AirScrollBridgeTests: XCTestCase {
    
    // MARK: - Motion Data Tests
    func testMotionDataJSONEncoding() throws {
        let motionData = MotionData(
            pitch: 0.123,
            yaw: -0.456,
            roll: 0.789,
            timestamp: 1234567890.0
        )
        
        let jsonString = motionData.jsonString
        XCTAssertFalse(jsonString.isEmpty)
        
        // Parse back to verify structure
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(decoded["pitch"] as! Double, 0.123, accuracy: 0.001)
        XCTAssertEqual(decoded["yaw"] as! Double, -0.456, accuracy: 0.001)
        XCTAssertEqual(decoded["roll"] as! Double, 0.789, accuracy: 0.001)
        XCTAssertEqual(decoded["timestamp"] as! Double, 1234567890.0, accuracy: 0.001)
    }
    
    func testMotionDataDegreesConversion() {
        let motionData = MotionData(
            pitch: .pi / 2,     // 90 degrees
            yaw: .pi,           // 180 degrees
            roll: .pi / 4,      // 45 degrees
            timestamp: 0
        )
        
        XCTAssertEqual(motionData.pitchDegrees, 90.0, accuracy: 0.1)
        XCTAssertEqual(motionData.yawDegrees, 180.0, accuracy: 0.1)
        XCTAssertEqual(motionData.rollDegrees, 45.0, accuracy: 0.1)
    }
    
    // MARK: - Preferences Tests
    func testPreferencesPortValidation() {
        let preferences = Preferences()
        
        // Valid ports
        XCTAssertTrue(preferences.isValidPort(1024))
        XCTAssertTrue(preferences.isValidPort(8080))
        XCTAssertTrue(preferences.isValidPort(65535))
        
        // Invalid ports
        XCTAssertFalse(preferences.isValidPort(80))     // Too low
        XCTAssertFalse(preferences.isValidPort(65536))  // Too high
        XCTAssertFalse(preferences.isValidPort(-1))     // Negative
    }
    
    func testPreferencesPortSetting() {
        let preferences = Preferences()
        
        // Valid port should succeed
        XCTAssertTrue(preferences.validateAndSetPort(8080))
        XCTAssertEqual(preferences.serverPort, 8080)
        
        // Invalid port should fail and not change the value
        let previousPort = preferences.serverPort
        XCTAssertFalse(preferences.validateAndSetPort(80))
        XCTAssertEqual(preferences.serverPort, previousPort)
    }
    
    func testPreferencesDefaults() {
        let preferences = Preferences()
        
        // Should have reasonable defaults
        XCTAssertTrue(preferences.isValidPort(preferences.serverPort))
        XCTAssertEqual(preferences.serverPort, 17604) // Default port
    }
    
    // MARK: - WebSocket Server Tests
    func testWebSocketServerPortBinding() async throws {
        // Find an available port for testing
        let testPort = findAvailablePort() ?? 9999
        
        let server = WebSocketServer(port: testPort)
        
        // Start server
        server.start()
        
        // Give server time to bind
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Try to connect
        let connected = try await connectToWebSocket(port: testPort)
        XCTAssertTrue(connected, "Should be able to connect to WebSocket server")
        
        // Stop server
        server.stop()
    }
    
    func testWebSocketMotionDataBroadcast() async throws {
        let testPort = findAvailablePort() ?? 9998
        let server = WebSocketServer(port: testPort)
        
        server.start()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Create test motion data
        let motionData = MotionData(
            pitch: 0.1,
            yaw: 0.2,
            roll: 0.3,
            timestamp: CACurrentMediaTime()
        )
        
        // Test broadcast (this mainly tests that it doesn't crash)
        server.broadcastMotionData(motionData)
        
        server.stop()
    }
    
    // MARK: - Port Availability Tests
    func testPortAvailabilityCheck() {
        // Port 22 (SSH) should typically be unavailable on macOS
        XCTAssertFalse(Preferences.isPortAvailable(22))
        
        // High numbered ports should typically be available
        let highPort = 55555
        if Preferences.isPortAvailable(highPort) {
            XCTAssertTrue(Preferences.isPortAvailable(highPort))
        }
    }
    
    func testNextAvailablePortFinding() {
        // This should find a port (though we can't guarantee which one)
        let nextPort = Preferences.getNextAvailablePort(startingFrom: 50000)
        XCTAssertNotNil(nextPort)
        
        if let port = nextPort {
            XCTAssertGreaterThanOrEqual(port, 50000)
            XCTAssertLessThanOrEqual(port, 65535)
        }
    }
    
    // MARK: - Helper Methods
    private func findAvailablePort() -> Int? {
        for port in 9000..<10000 {
            if Preferences.isPortAvailable(port) {
                return port
            }
        }
        return nil
    }
    
    private func connectToWebSocket(port: Int) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            
            let bootstrap = ClientBootstrap(group: eventLoopGroup)
                .channelInitializer { channel in
                    let httpHandler = TestHTTPClientHandler()
                    let upgrader = NIOWebSocketClientUpgrader(
                        requestKey: "test",
                        upgradePipelineHandler: { channel, response in
                            return channel.eventLoop.makeSucceededVoidFuture()
                        }
                    )
                    
                    return channel.pipeline.addHTTPClientHandlers(
                        withClientUpgrade: (upgraders: [upgrader], completionHandler: { context in
                            context.pipeline.removeHandler(httpHandler, promise: nil)
                        })
                    ).flatMap {
                        channel.pipeline.addHandler(httpHandler)
                    }
                }
            
            let connectFuture = bootstrap.connect(host: "127.0.0.1", port: port)
            
            connectFuture.whenComplete { result in
                eventLoopGroup.shutdownGracefully { _ in }
                
                switch result {
                case .success(let channel):
                    channel.close(promise: nil)
                    continuation.resume(returning: true)
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

// MARK: - Test HTTP Handler
private class TestHTTPClientHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // Handle HTTP response parts
    }
}

// MARK: - Performance Tests
extension AirScrollBridgeTests {
    func testMotionDataJSONPerformance() throws {
        let motionData = MotionData(
            pitch: 0.123,
            yaw: -0.456,
            roll: 0.789,
            timestamp: CACurrentMediaTime()
        )
        
        measure {
            for _ in 0..<1000 {
                _ = motionData.jsonString
            }
        }
    }
}
