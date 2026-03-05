// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "linkage-test",
    dependencies: [
        .package(name: "swift-java-jni-core", path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "linkageTest",
            dependencies: [
                .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core")
            ]
        )
    ]
)
