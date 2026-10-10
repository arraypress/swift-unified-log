// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-unified-log",
    // OSLogStore(scope: .system) arrived on macOS 12. No UI framework.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "UnifiedLog", targets: ["UnifiedLog"]),
    ],
    targets: [
        // Catches the Objective-C exception a malformed predicate raises.
        .target(name: "SafePredicate"),
        .target(name: "UnifiedLog", dependencies: ["SafePredicate"]),
        .testTarget(name: "UnifiedLogTests", dependencies: ["UnifiedLog"]),
    ]
)
