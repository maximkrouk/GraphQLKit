// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "GraphQLKit",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "GraphQLKit",
            targets: ["GraphQLKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/maximkrouk/Graphiti.git", from: "1.0.0-beta.1.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-beta"),
    ],
    targets: [
        .target(name: "GraphQLKit", dependencies: [
            .product(name: "Graphiti", package: "Graphiti"),
            .product(name: "Vapor", package: "vapor")
        ]),
        .testTarget(name: "GraphQLKitTests",dependencies: [
            .target(name: "GraphQLKit"),
            .product(name: "XCTVapor", package: "vapor")
        ])
    ]
)
