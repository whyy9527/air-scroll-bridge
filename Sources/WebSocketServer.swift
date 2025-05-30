import Foundation
import NIO
import NIOWebSocket
import NIOHTTP1
import NIOPosix
import Combine

class WebSocketServer: ObservableObject {
    // MARK: - Properties
    private var eventLoopGroup: EventLoopGroup?
    private var channel: Channel?
    private var isRunning = false
    private let port: Int
    
    // Connected clients
    private var connectedClients = Set<WebSocketClient>()
    private let clientsLock = NSLock()
    
    // Publishers
    private let connectionCountSubject = CurrentValueSubject<Int, Never>(0)
    var connectionCountPublisher: AnyPublisher<Int, Never> {
        connectionCountSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init(port: Int = 17604) {
        self.port = port
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Server Lifecycle
    func start() {
        guard !isRunning else {
            print("⚠️ WebSocket server already running on port \(port)")
            return
        }
        
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        
        let bootstrap = ServerBootstrap(group: eventLoopGroup!)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                self.configureChildChannel(channel)
            }
            .childChannelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        do {
            channel = try bootstrap.bind(host: "127.0.0.1", port: port).wait()
            isRunning = true
            print("🚀 WebSocket server started on ws://localhost:\(port)/")
        } catch {
            print("❌ Failed to start WebSocket server: \(error)")
            eventLoopGroup?.shutdownGracefully { _ in }
            eventLoopGroup = nil
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        
        // Close all client connections
        clientsLock.lock()
        for client in connectedClients {
            client.close()
        }
        connectedClients.removeAll()
        clientsLock.unlock()
        
        updateConnectionCount()
        
        // Close server channel
        channel?.close(mode: .all, promise: nil)
        channel = nil
        
        // Shutdown event loop group
        eventLoopGroup?.shutdownGracefully { error in
            if let error = error {
                print("❌ Error shutting down event loop group: \(error)")
            }
        }
        eventLoopGroup = nil
        
        print("⏹️ WebSocket server stopped")
    }
    
    // MARK: - Channel Configuration
    private func configureChildChannel(_ channel: Channel) -> EventLoopFuture<Void> {
        let httpHandler = HTTPHandler()
        let webSocketUpgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { channel, head in
                return channel.eventLoop.makeSucceededFuture(HTTPHeaders())
            },
            upgradePipelineHandler: { channel, head in
                return self.configureWebSocketPipeline(channel)
            }
        )
        
        let config = NIOHTTPServerUpgradeConfiguration(
            upgraders: [webSocketUpgrader],
            completionHandler: { context in
                // Remove HTTP handlers after upgrade - use string name for removal
                _ = context.pipeline.removeHandler(name: "http-handler")
            }
        )
        
        return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
            channel.pipeline.addHandler(httpHandler, name: "http-handler")
        }
    }
    
    private func configureWebSocketPipeline(_ channel: Channel) -> EventLoopFuture<Void> {
        let webSocketHandler = WebSocketHandler { [weak self] client in
            self?.addClient(client)
        } onDisconnect: { [weak self] client in
            self?.removeClient(client)
        }
        
        return channel.pipeline.addHandler(webSocketHandler)
    }
    
    // MARK: - Client Management
    private func addClient(_ client: WebSocketClient) {
        clientsLock.lock()
        connectedClients.insert(client)
        clientsLock.unlock()
        
        updateConnectionCount()
        print("📱 Client connected (total: \(connectedClients.count))")
    }
    
    private func removeClient(_ client: WebSocketClient) {
        clientsLock.lock()
        connectedClients.remove(client)
        clientsLock.unlock()
        
        updateConnectionCount()
        print("📱 Client disconnected (total: \(connectedClients.count))")
    }
    
    private func updateConnectionCount() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectionCountSubject.send(self.connectedClients.count)
        }
    }
    
    // MARK: - Broadcasting
    func broadcastMotionData(_ motionData: MotionData) {
        guard !connectedClients.isEmpty else { return }
        
        let jsonString = motionData.jsonString
        
        clientsLock.lock()
        let clients = Array(connectedClients)
        clientsLock.unlock()
        
        for client in clients {
            client.send(jsonString)
        }
    }
}

// MARK: - HTTP Handler
private class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            if head.uri != "/" {
                sendNotFoundResponse(context: context)
            }
        case .body, .end:
            break
        }
    }
    
    private func sendNotFoundResponse(context: ChannelHandlerContext) {
        let responseHead = HTTPResponseHead(
            version: .init(major: 1, minor: 1),
            status: .notFound
        )
        context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
        
        let buffer = context.channel.allocator.buffer(string: "WebSocket endpoint available at /")
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

// MARK: - WebSocket Handler
fileprivate class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame
    
    private let onConnect: (WebSocketClient) -> Void
    private let onDisconnect: (WebSocketClient) -> Void
    private var client: WebSocketClient?
    
    init(onConnect: @escaping (WebSocketClient) -> Void, onDisconnect: @escaping (WebSocketClient) -> Void) {
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        client = WebSocketClient(context: context, handler: self)
        if let client = client {
            onConnect(client)
        }
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        if let client = client {
            onDisconnect(client)
        }
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        
        switch frame.opcode {
        case .connectionClose:
            context.close(promise: nil)
        case .ping:
            let pongFrame = WebSocketFrame(fin: true, opcode: .pong, data: frame.data)
            context.writeAndFlush(Self.wrapOutboundOut(pongFrame), promise: nil)
        case .text, .binary:
            // Echo received messages (optional, for testing)
            context.writeAndFlush(data, promise: nil)
        default:
            break
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("❌ WebSocket error: \(error)")
        context.close(promise: nil)
    }
}

// MARK: - WebSocket Client
class WebSocketClient: Hashable, Equatable {
    private let context: ChannelHandlerContext
    private let handler: WebSocketHandler
    private let id = UUID()
    
    fileprivate init(context: ChannelHandlerContext, handler: WebSocketHandler) {
        self.context = context
        self.handler = handler
    }
    
    func send(_ message: String) {
        guard context.channel.isActive else { return }
        
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        context.writeAndFlush(WebSocketHandler.wrapOutboundOut(frame), promise: nil)
    }
    
    func close() {
        context.close(promise: nil)
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WebSocketClient, rhs: WebSocketClient) -> Bool {
        return lhs.id == rhs.id
    }
}
