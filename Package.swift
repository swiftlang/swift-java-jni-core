// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
  name: "swift-java-jni-core",
  products: [
    .library(
      name: "SwiftJavaJNICore",
      targets: ["SwiftJavaJNICore"]
    )
  ],
  targets: [
    .target(
      name: "CSwiftJavaJNI"
    ),

    .target(
      name: "SwiftJavaJNICore",
      dependencies: [
        "CSwiftJavaJNI"
      ]
    ),

    .testTarget(
      name: "SwiftJavaJNICoreTests",
      dependencies: [
        "SwiftJavaJNICore"
      ]
    ),
  ]
)
