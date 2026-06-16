// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteRecruit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "RemoteRecruit", targets: ["RemoteRecruit"]),
    ],
    targets: [
        .target(
            name: "RemoteRecruit",
            path: "Sources/RemoteRecruit"
        ),
        .testTarget(
            name: "RemoteRecruitTests",
            dependencies: ["RemoteRecruit"],
            path: "Tests/RemoteRecruitTests"
        )
    ]
)
