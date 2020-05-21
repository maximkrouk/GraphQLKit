import GraphQL
import Vapor

extension GraphQLError: AbortError {
    // As far as I understood it should be handled on client by content, not by response status, so it's 200 (OK)
    public var status: HTTPResponseStatus { .ok }
    public var identifier: String { "GraphQLError" }
    public var reason: String { message }
}

extension Abort: SelfEncodableError {
    public func encode() -> String {
        """
        {"abort":{"code":\(status.code),"reason":\"\(reason)\"}}
        """
    }
}
