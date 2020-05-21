# GraphQLKit
[![Language](https://img.shields.io/badge/Swift-5.2-brightgreen.svg)](http://swift.org) [![Vapor Version](https://img.shields.io/badge/Vapor-4-FA6878.svg)](http://vapor.codes) [![build](https://github.com/maximkrouk/GraphQLKit/workflows/build/badge.svg)](https://github.com/maximkrouk/graphql-kit/actions)


Easy setup of a GraphQL server with Vapor. It uses the GraphQL implementation of [Graphiti](https://github.com/maximkrouk/Graphiti).

## Features
- [x] Arguments, operation name and query support
- [x] Normal access to the `Request` object as in normal Vapor request handlers
- [x] Accept JSON in the body of a POST request as the GraphQL query
- [x] POST and GET support
- [x] Static controllers support
- [ ] A nice example _(even with a bit of frontend JS_ 😉_)_  _`in progress`_
- [ ] Accept `application/graphql` content type requests
- [ ] Downloadable schema file
- [ ] Multi-Resolver support

## Installation

Add the package to Your SwiftPM package dependencies:

```swift
.package(
    url: "https://github.com/maximkrouk/GraphQLKit.git", 
    from: "1.0.0-beta.1.0"
)
```

then add `GraphQL` dependency to your target:

```swift
.product(name: "GraphQLKit", package: "GraphQLKit")
```

## Getting Started
### Define your schema
This package is setup to accept only `Request` objects as the context object for the schema. This gives the opportunity to access all functionality that Vapor provides, for example authentication, service management and database access.
This package only provides the needed functions to register an existing GraphQL schema on a Vapor application. To define your schema please refer to the [Graphiti](https://github.com/maximkrouk/Graphiti) documentations.
But by including this package some other helper functions are exposed:

#### Async Resolvers
An `EventLoopGroup` parameter is no longer required for async resolvers as the `Request` context object already provides access to it's `EventLoopGroup` attribute `eventLoop`.

```Swift
struct SomeAPIController: FieldKeyProvider {
    ///...
  
    // Instead of adding an unnecessary parameter
    func getAllTodos(_ req: Request, arguments: NoArguments, _: EventLoopGroup) throws -> EventLoopFuture<[Todo]> {
        Todo.query(on: req.db).all()
    }

    // You don't need to provide the eventLoopGroup parameter even when resolving a future.
    func getAllTodos(_ req: Request, arguments: NoArguments) throws -> EventLoopFuture<[Todo]> {
        Todo.query(on: req.db).all()
    }
}
```

#### Static Resolvers

Use static resolvers with th help of `QLResolverProvider` type.

```Swift
typealias SomeAPIProvider = StaticFieldKeyProviderType<SomeAPIController>
enum SomeAPIController: FieldKeyProvider {
    ///...
  
    // You don't need to provide the eventLoopGroup parameter even when resolving a future.
    static func getAllTodos(_ req: Request, arguments: NoArguments) throws -> EventLoopFuture<[Todo]> {
        Todo.query(on: req.db).all()
    }
}
```

> Example for static REST controller can be found [here](https://gist.github.com/maximkrouk/7dccc660f917e634b3b6cfea006e5cee)

#### Enums

It automatically resolves all cases of an enum if the type conforms to `CaseIterable`. 
```swift
enum TodoState: String, CaseIterable {
    case open
    case done
    case forLater
}

Enum(TodoState.self),
```

### Register the schema on the application
```Swift
// Register the schema and it's resolver.
app.graphQL("graphQL", schema: todoSchema, use: TodoAPIProvider())
```

> This API may change a bit, schema has enough information for routing (at least static routing), so I'll figure out how to get it from here, not from APIProvider instance.

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

## Contribution
You can contribute to this project by submitting a detailed issue or by forking this project and sending a pull request. Contributions of any kind are very welcome :)
