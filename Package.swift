// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenShelf",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ScreenShelf",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/ScreenShelf",
            exclude: ["Info.plist", "Icons"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/ScreenShelf/Info.plist",
                ])
            ]
        )
    ]
)
