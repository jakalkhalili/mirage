let routes = makeRoutes {
    pathPrefix("/api") {
        path("/ping") {
            // GET /api/ping
            get {
                respond("pong", status: .ok)
            }
        }
    }
}

// Run HTTP server on :8080
try bootServer(routes, host: "0.0.0.0", port: 8080)