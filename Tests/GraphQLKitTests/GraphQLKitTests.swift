import XCTest
import Vapor
import XCTVapor
@testable import GraphQLKit

final class GraphQLKitTests: XCTestCase {
    struct SomeBearerAuthenticator: BearerAuthenticator {
        struct User: Authenticatable {}
        
        func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<User?> {
            // Bearer token should be equal to `token` to pass the auth
            if bearer.token == "token" {
                return request.eventLoop.makeSucceededFuture(User())
            } else {
                return request.eventLoop.makeFailedFuture(Abort(.unauthorized))
            }
        }
        
        func authenticate(request: Request) -> EventLoopFuture<User?> {
            // Bearer token should be equal to `token` to pass the auth
            if request.headers.bearerAuthorization?.token == "token" {
                return request.eventLoop.makeSucceededFuture(User())
            } else {
                return request.eventLoop.makeFailedFuture(Abort(.unauthorized))
            }
        }
    }
    
    typealias ProtectedResolverAPI = StaticFieldKeyProviderType<ProtectedResolver>
    enum ProtectedResolver: FieldKeyProvider {
        typealias FieldKey = FieldKeys

        enum FieldKeys: String {
            case test
            case number
        }
        
        static func test(_ req: Request, _: NoArguments) throws -> EventLoopFuture<String> {
            _ = try req.auth.require(SomeBearerAuthenticator.User.self)
            return req.eventLoop.makeSucceededFuture("Hello World")
        }

        static func number(_ req: Request, _: NoArguments) throws -> EventLoopFuture<Int> {
            _ = try req.auth.require(SomeBearerAuthenticator.User.self)
            return req.eventLoop.makeSucceededFuture(42)
        }
    }
    
    struct Resolver: FieldKeyProvider {
        typealias FieldKey = FieldKeys

        enum FieldKeys: String {
            case test
            case number
        }
        func test(store: Request, _: NoArguments) -> String {
            "Hello World"
        }

        func number(store: Request, _: NoArguments) -> Int {
            42
        }
    }
    
    let protectedSchema = QLSchema<ProtectedResolverAPI, Request>([
        QLQuery([
            QLField(ProtectedResolver.self, .test) { $0.test },
            QLField(ProtectedResolver.self, .number) { $0.number }
        ])
    ])

    let schema = QLSchema<Resolver, Request>([
        QLQuery([
            QLField(.test, at: Resolver.test),
            QLField(.number, at: Resolver.number)
        ])
    ])
    
    let query = """
    query {
        test
    }
    """

    func testPostEndpoint() throws {
        let queryRequest = QueryRequest(query: query, operationName: nil, variables: nil)
        let data = String(data: try! JSONEncoder().encode(queryRequest), encoding: .utf8)!

        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.graphQL("graphql", schema: schema, use: Resolver())

        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(data)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
        headers.contentType = .json

        try app.testable().test(.POST, "/graphql", headers: headers, body: body) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.description, #"{"data":{"test":"Hello World"}}"#)
        }
    }

    func testGetEndpoint() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.graphQL("graphql", schema: schema, use: Resolver())
        try app.testable().test(.GET, "/graphql?query=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.description, #"{"data":{"test":"Hello World"}}"#)
        }
    }
    
    func testPostOperatinName() throws {
        let multiQuery = """
            query World {
                test
            }

            query Number {
                number
            }
            """
        let queryRequest = QueryRequest(query: multiQuery, operationName: "Number", variables: nil)
        let data = String(data: try! JSONEncoder().encode(queryRequest), encoding: .utf8)!

        let app = Application(.testing)
        defer { app.shutdown() }
        
        app.graphQL("graphql", schema: schema, use: Resolver())
        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(data)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
        headers.contentType = .json

        try app.testable().test(.POST, "/graphql", headers: headers, body: body) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.description, #"{"data":{"number":42}}"#)
        }
    }
    
    func testProtectedPostEndpoint() throws {
        let queryRequest = QueryRequest(query: query, operationName: nil, variables: nil)
        let data = String(data: try! JSONEncoder().encode(queryRequest), encoding: .utf8)!

        let app = Application(.testing)
        defer { app.shutdown() }

        let protected = app.grouped(SomeBearerAuthenticator().middleware())
        protected.graphQL("graphql", schema: protectedSchema, use: ProtectedResolverAPI())

        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(data)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
        headers.contentType = .json
        
        var protectedHeaders = headers
        protectedHeaders.replaceOrAdd(name: .authorization, value: "Bearer token")
        
        try app.testable().test(.POST, "/graphql", headers: headers, body: body) { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
        
        try app.testable().test(.POST, "/graphql", headers: protectedHeaders, body: body) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.description, #"{"data":{"test":"Hello World"}}"#)
        }
    }
    
    func testProtectedGetEndpoint() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        let protected = app.grouped(SomeBearerAuthenticator().middleware())
        protected.graphQL("graphql", schema: protectedSchema, use: ProtectedResolver.eraseToAnyFieldKeyProviderType())
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .authorization, value: "Bearer token")
        
        try app.testable().test(.GET, "/graphql?query=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)") { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
        
        try app.testable().test(.GET, "/graphql?query=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)", headers: headers) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.description, #"{"data":{"test":"Hello World"}}"#)
        }
    }
    
    func testProtectedPostOperatinName() throws {
        let multiQuery = """
            query World {
                test
            }

            query Number {
                number
            }
            """
        let queryRequest = QueryRequest(query: multiQuery, operationName: "Number", variables: nil)
        let data = String(data: try! JSONEncoder().encode(queryRequest), encoding: .utf8)!

        let app = Application(.testing)
        defer { app.shutdown() }

        let protected = app.grouped(SomeBearerAuthenticator().middleware())
        protected.graphQL("graphql", schema: protectedSchema, use: ProtectedResolverAPI())

        var body = ByteBufferAllocator().buffer(capacity: 0)
        body.writeString(data)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentLength, value: body.readableBytes.description)
        headers.contentType = .json
        
        var protectedHeaders = headers
        protectedHeaders.replaceOrAdd(name: .authorization, value: "Bearer token")
        
        try app.testable().test(.POST, "/graphql", headers: headers, body: body) { res in
            XCTAssertEqual(res.status, .unauthorized)
        }

        try app.testable().test(.POST, "/graphql", headers: protectedHeaders, body: body) { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.description, #"{"data":{"number":42}}"#)
        }
    }

    static let allTests = [
        ("testPostEndpoint", testPostEndpoint),
        ("testGetEndpoint", testGetEndpoint),
        ("testPostOperatinName", testPostOperatinName),
        ("testProtectedPostEndpoint", testPostEndpoint),
        ("testProtectedGetEndpoint", testGetEndpoint),
        ("testProtectedPostOperatinName", testPostOperatinName),
    ]
}
