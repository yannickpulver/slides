// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SlidesCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SlidesCore", targets: ["SlidesCore"])
    ],
    targets: [
        .target(
            name: "SlidesCore",
            resources: [.copy("Resources/FilmEdges")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SlidesCoreTests",
            dependencies: ["SlidesCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
