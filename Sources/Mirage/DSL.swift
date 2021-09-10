import NIOCore
import NIOPosix
import NIOHTTP1

public typealias ActionHandler = () -> Result

public struct Action {
    var handler: ActionHandler
    var method: HTTPMethod
}

@resultBuilder
public struct ActionsBuilder {
    static func buildBlock(_ actions: Action...) -> [Action] { 
        actions
    }
}

public struct Route {
    var path: String
    var pathPrefix: String? = nil
    var actions: [Action]
}

@resultBuilder
struct RoutesBuilder {
    static func buildBlock(_ routes: RouteConvertible...) -> [Route] { 
        routes.flatMap { $0.asRoutes() }
    }
}

public struct RouteGroup {
    var pathPrefix: String
    var routes: [Route] 
}

protocol RouteConvertible {
    func asRoutes() -> [Route]
}

extension Route: RouteConvertible {
    func asRoutes() -> [Route] { [self] }
    func getPath() -> String { (self.pathPrefix ?? "") + self.path }
}

extension RouteGroup: RouteConvertible {
    func asRoutes() -> [Route] {
        self.routes.map {
            return Route(path: $0.path, pathPrefix: self.pathPrefix, actions: $0.actions)
        }
    }
}

func makeRoutes(@RoutesBuilder _ content: () -> [Route]) -> [Route] {
    content()
}

func pathPrefix(_ pathPrefix: String, @RoutesBuilder _ builder: () -> [Route]) -> RouteGroup {
    return .init(pathPrefix: pathPrefix, routes: builder())
}

public func path(_ path: String = "/", @ActionsBuilder _ builder: () -> [Action]) -> Route {
    return .init(path: path, actions: builder())
}

public func handle(_ handler: @escaping ActionHandler, method: HTTPMethod) -> Action {
    return .init(handler: handler, method: method)
}

// - MARK HTTP methods

public func get(_ handler: @escaping ActionHandler) -> Action {
    return handle(handler, method: .GET)
}

public func post(_ handler: @escaping ActionHandler) -> Action {
    return handle(handler, method: .POST)
}

public func delete(_ handler: @escaping ActionHandler) -> Action {
    return handle(handler, method: .DELETE)
}

public func put(_ handler: @escaping ActionHandler) -> Action {
    return handle(handler, method: .PUT)
}

public struct Result {
    var message: String
    var status: HTTPResponseStatus
    var headers: HTTPHeaders
    var contentType: String
}

public func respond(_ message: String, status: HTTPResponseStatus = .ok, headers: HTTPHeaders = HTTPHeaders(), contentType: String = "application/octet-stream") -> Result {
    return .init(message: message, status: status, headers: headers, contentType: contentType)
}