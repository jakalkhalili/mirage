import NIOCore
import NIOPosix
import NIOHTTP1
import Logging

public class ServerHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart

    private var routes: [Route]
    private let logger = Logger(label: "MirageServerHandler")

    public init(routes: [Route]) {
        self.routes = routes
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let req = self.unwrapInboundIn(data)
        
        if case let .head(req) = req {
            logger.info("\(req.method.rawValue) \(req.uri) --- \(req.headers.description)")
            let route = routes.filter { $0.getPath() == req.uri }.first
            guard let route = route else {
                self.serialize(respond("Not Found", status: .notFound), context: context)
                return
            }

            let action = route.actions.filter { $0.method == req.method }.first
            guard let action = action else {
                self.serialize(respond("Not Found", status: .notFound), context: context)
                return
            }

            let result = action.handler()
            self.serialize(result, context: context)
        }
    }

    public func serialize(_ result: Result, context: ChannelHandlerContext) {
        context.write(self.wrapOutboundOut(.head(.init(version: .http1_1, status: result.status, headers: result.headers))), promise: nil)

        var buffer = context.channel.allocator.buffer(capacity: result.message.utf8.count)
        buffer.writeString(result.message)

        context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }
}

func childChannelInitializer(routes: [Route], channel: Channel) -> EventLoopFuture<Void> {
    return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
        channel.pipeline.addHandler(ServerHandler(routes: routes))
    }
}

public func bootServer(_ routes: [Route], host: String, port: Int, wait: Bool = true) throws {
    let logger = Logger(label: "MirageServer")

    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let socketBootstrap = ServerBootstrap(group: group)
                            .serverChannelOption(ChannelOptions.backlog, value: 256)
                            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                            .childChannelInitializer{channel in childChannelInitializer(routes: routes, channel: channel)}
                            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
                            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: false)

    defer {
        try! group.syncShutdownGracefully()
    }

    let channel = try { () -> Channel in 
        return try socketBootstrap.bind(host: host, port: port).wait()
    }()

    logger.info("Server started!")
    
    // This function should be redesigned without the wait variable
    if wait {
        try channel.closeFuture.wait()
    }

    logger.info("Server closed")
}