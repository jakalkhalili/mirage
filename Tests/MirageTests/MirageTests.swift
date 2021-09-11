import XCTest
@testable import Mirage

final class MirageTests: XCTestCase {
    func testBootingServer() {
        let port = Int.random(in: 10000..<12500)
        let routes = makeRoutes{}
        do {
            try bootServer(routes, host: "localhost", port: port, wait: false)
        } catch {
            XCTFail("Unexpected error thrown when server was trying to boot")
        }
    }
}
