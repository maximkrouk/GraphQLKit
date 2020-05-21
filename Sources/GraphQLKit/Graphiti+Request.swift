import Vapor
import GraphQL

extension Request {
    func resolveByBody<Resolver: FieldKeyProvider>(
        graphQLSchema schema: QLSchema<Resolver, Request>,
        with resolver: Resolver
    ) throws -> Future<String> {
        let queryRequest = try self.content
            .decode(QueryRequest.self)
        return self.resolve(
            queryRequest,
            schema: schema,
            with: resolver
        )
    }

    func resolveByQueryParameters<Resolver: FieldKeyProvider>(
        graphQLSchema schema: QLSchema<Resolver, Request>,
        with resolver: Resolver
    ) throws -> Future<String> {
        guard let queryString = self.query[String.self, at: "query"] else { throw GraphQLError(GraphQLResolveError.noQueryFound) }
        let variables = self.query[String.self, at: "variables"].flatMap {
            $0.data(using: .utf8).flatMap { (data) -> [String: Map]? in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try? decoder.decode([String: Map]?.self, from: data)
            }
        }

        let operationName = self.query[String.self, at: "operationName"]
        let queryRequest = QueryRequest(query: queryString, operationName: operationName, variables: variables)
        return resolve(queryRequest, schema: schema, with: resolver)
    }

    private func resolve<Resolver: FieldKeyProvider>(
        _ request: QueryRequest,
        schema: QLSchema<Resolver, Request>,
        with resolver: Resolver
    ) -> Future<String> {
        schema.execute(
            request: request.query,
            resolver: resolver,
            context: self,
            eventLoopGroup: self.eventLoop,
            variables: request.variables ?? [:],
            operationName: request.operationName
        )
        .map({ $0.description })
    }
}
