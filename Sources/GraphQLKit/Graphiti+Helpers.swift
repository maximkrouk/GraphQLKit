// NOTE: Not sure if I need it
// But there is usefull stuff lower at MARK
import Vapor
import GraphQL

public typealias SimpleAsyncResolve<ObjectType, Context, Arguments, ResolveType> = (
    _ object: ObjectType
)  -> (
    _ context: Context,
    _ arguments: Arguments
) throws -> EventLoopFuture<ResolveType>

public struct StaticFieldKeyProviderType<Wrapped: FieldKeyProvider>: FieldKeyProvider {
    public typealias FieldKey = Wrapped.FieldKey
    public init() {}
}

extension FieldKeyProvider {
    public static func eraseToAnyFieldKeyProviderType() -> StaticFieldKeyProviderType<Self> { .init() }
}

extension Graphiti.QLField {
    convenience public init(
        name: String,
        at function: @escaping SimpleAsyncResolve<ObjectType, Context, Arguments, ResolveType>
    ) {
        let name = name

        let resolve: GraphQLFieldResolve = { source, arguments, context, eventLoopGroup, _ in
            guard let s = source as? ObjectType else {
                throw GraphQLError(message: "Expected source type \(ObjectType.self) but got \(type(of: source))")
            }

            guard let c = context as? Context else {
                throw GraphQLError(message: "Expected context type \(Context.self) but got \(type(of: context))")
            }

            let a = try MapDecoder().decode(Arguments.self, from: arguments)

            return  try function(s)(c, a).map({ $0 })
        }

        self.init(name: name, resolve: resolve)
    }
}

extension Graphiti.QLField where FieldType == ResolveType {
    public convenience init(
        _ name: FieldKey,
        with function: @escaping SimpleAsyncResolve<ObjectType, Context, Arguments, ResolveType>
    )  {
        self.init(name: name.rawValue, at: function)
    }
}

extension Graphiti.QLField where Arguments == NoArguments {
    public convenience init(
        _ name: FieldKey,
        with function: @escaping SimpleAsyncResolve<ObjectType, Context, Arguments, ResolveType>,
        overridingType: FieldType.Type = FieldType.self
    )  {
        self.init(name: name.rawValue, at: function)
    }
}

// MARK: - Usefull stuff

extension QLType {
    public static func named(
        _ type: ObjectType.Type,
        fields components: [QLObjectTypeComponent<ObjectType, ObjectType.FieldKey, Context>]
    ) -> QLType<Resolver, Context , ObjectType> { .init(type, name: String(describing: type), fields: components) }
}

public func _QLType<Root: FieldKeyProvider, Context, ObjectType: Encodable & FieldKeyProvider>(
    _ type: ObjectType.Type,
    fields components: [QLObjectTypeComponent<ObjectType, ObjectType.FieldKey, Context>]
) -> QLType<Root, Context, ObjectType> { .named(type, fields: components) }

func wrap<ObjectType, Context, Arguments, ResolveType>(
    _ function: @escaping (
        _ context: Context,
        _ arguments: Arguments
    ) throws -> EventLoopFuture<ResolveType>
) -> AsyncResolve<ObjectType, Context, Arguments, ResolveType> {
    { _ in { ctx, args, elg in try function(ctx, args) } }
}

extension QLField where FieldType == ResolveType {
    public convenience init<T: FieldKeyProvider>(
        _ name: FieldKey,
        at function: @escaping (
            _ context: Context,
            _ arguments: Arguments
        ) throws -> EventLoopFuture<ResolveType>
    ) where ObjectType == StaticFieldKeyProviderType<T> {
        self.init(name, at: wrap(function))
    }
}

extension QLField where FieldType == ResolveType {
    public convenience init<T: FieldKeyProvider>(
        _ type: T.Type,
        _ name: FieldKey,
        builder: (T.Type) ->  (
            _ context: Context,
            _ arguments: Arguments
        ) throws -> EventLoopFuture<ResolveType>
    ) where ObjectType == StaticFieldKeyProviderType<T> {
        self.init(name, at: builder(type))
    }
}
