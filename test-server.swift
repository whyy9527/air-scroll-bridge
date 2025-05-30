#!/usr/bin/env swift

import Foundation
import NIO
import NIOWebSocket
import NIOHTTP1

// Simple test WebSocket server without GUI components
class SimpleWebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        
        switch frame.opcode {
        case .connectionClose:
            context.close(promise: nil)
        case .ping:
            let pongFrame = WebSocketFrame(fin: true, opcode: .pong, data: frame.data)
            context.writeAndFlush(self.wrapOutboundOut(pongFrame), promise: nil)
        case .text:
            let text = String(buffer: frame.data)
            print("📩 Received: \(text)")
            
            // Send test motion data
            let testData = """
            {
                "type": "motion",
                "timestamp": \(Date().timeIntervalSince1970),
                "attitude": {
                    "pitch": 0.1,
                    "roll": -0.05,
                    "yaw": 0.02
                },
                "rotationRate": {
                    "x": 0.01,
                    "y": -0.02,
                    "z": 0.003
                }
            }
            """
            
            let responseFrame = WebSocketFrame(fin: true, opcode: .text, data: ByteBuffer(string: testData))
            context.writeAndFlush(self.wrapOutboundOut(responseFrame), promise: nil)
        default:
            break
        }
    }
    
    func channelActive(context: ChannelHandlerContext) {
        print("✅ WebSocket client connected")
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        print("❌ WebSocket client disconnected")
    }
}

class SimpleWebSocketUpgrader: HTTPServerProtocolUpgrader {
    let supportedProtocol: String = "websocket"
    let requiredUpgradeHeaders: [String] = ["upgrade", "connection", "sec-websocket-key", "sec-websocket-version"]
    
    func buildUpgradeResponse(channel: Channel, upgradeRequest: HTTPRequestHead, initialResponseHeaders: HTTPHeaders) -> EventLoopFuture<HTTPHeaders> {
        return WebSocketUpgrader.buildUpgradeResponse(channel: channel, upgradeRequest: upgradeRequest, initialResponseHeaders: initialResponseHeaders)
    }
    
    func upgrade(context: ChannelHandlerContext, upgradeRequest: HTTPRequestHead) -> EventLoopFuture<Void> {
        return WebSocketUpgrader.upgrade(context: context, upgradeRequest: upgradeRequest) { channel in
            return channel.pipeline.addHandler(SimpleWebSocketHandler())
        }
    }
}

// Create and start server
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
defer {
    try! group.syncShutdownGracefully()
}

let bootstrap = ServerBootstrap(group: group)
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelInitializer { channel in
        let httpHandler = HTTPHandler()
        let config = HTTPUpgradeConfiguration(
            upgraders: [SimpleWebSocketUpgrader()],
            completionHandler: { _ in }
        )
        
        return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
            channel.pipeline.addHandler(httpHandler)
        }
    }
    .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let request):
            if request.uri == "/health" {
                let headers = HTTPHeaders([("Content-Type", "text/plain")])
                let head = HTTPResponseHead(version: request.version, status: .ok, headers: headers)
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                
                var buffer = ByteBuffer.allocator.buffer(capacity: 12)
                buffer.writeString("Server OK\n")
                context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            } else {
                let head = HTTPResponseHead(version: request.version, status: .notFound)
                context.write(self.wrapOutboundOut(.head(head)), promise: nil)
                context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            }
        case .body, .end:
            break
        }
    }
}

do {
    let channel = try bootstrap.bind(host: "127.0.0.1", port: 17604).wait()
    print("🚀 Test WebSocket server started on port 17604")
    print("💡 Test with: curl http://127.0.0.1:17604/health")
    print("💡 Or use the test_websocket.sh script")
    print("Press Ctrl+C to stop")
    
    try channel.closeFuture.wait()
} catch {
    print("❌ Failed to start server: \(error)")
}
