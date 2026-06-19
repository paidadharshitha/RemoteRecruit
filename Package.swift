// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteRecruit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RemoteRecruit", targets: ["RemoteRecruit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "RemoteRecruit",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ],
            path: "Sources/RemoteRecruit"
        ),
        .testTarget(
            name: "RemoteRecruitTests",
            dependencies: ["RemoteRecruit"],
            path: "Tests/RemoteRecruitTests"
        )
    ]
)
