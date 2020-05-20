import Vapor
import Graphiti
import GraphQL

extension RoutesBuilder {
    @discardableResult
    public func graphQL<Resolver: FieldKeyProvider>(
        _ path: PathComponent...,
        schema: Schema<Resolver, Request>,
        use resolver: Resolver
    ) -> [Route] {
        [
            self.post(path) { (request) -> EventLoopFuture<Response> in
            try request.resolveByBody(graphQLSchema: schema, with: resolver)
                .map({ (responseContent) in
                    Response(body: responseContent, mediaType: .json)
                })
            },
            self.get(path) { (request) -> EventLoopFuture<Response> in
                try request.resolveByQueryParameters(graphQLSchema: schema, with: resolver)
                    .map({ (responseContent) in
                    Response(body: responseContent, mediaType: .json)
                })
            }
        ]
    }
}

enum GraphQLResolveError: Swift.Error {
    case noQueryFound
}

extension Response {
    convenience init(body: String, mediaType: HTTPMediaType) {
        self.init(
            status: .ok,
            headers: HTTPHeaders(
                [ (HTTPHeaders.Name.contentType.description, mediaType.description) ]
            ),
            body: Body(string: body)
        )
    }
}
