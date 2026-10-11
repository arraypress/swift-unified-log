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

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
