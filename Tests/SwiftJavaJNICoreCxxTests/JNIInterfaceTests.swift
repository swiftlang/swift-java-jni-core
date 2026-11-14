//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJavaJNICore
import Testing

#if canImport(FoundationEssentials)
import class FoundationEssentials.ProcessInfo
#else
import class Foundation.ProcessInfo
#endif

@Suite
struct JNIInterfaceTests {
  static var isSupportedPlatform: Bool {
    #if os(Android)
    let defaultValue = "0"
    #else
    let defaultValue = "1"
    #endif
    return (ProcessInfo.processInfo.environment["SWIFT_JAVA_JNI_TEST_JVM"] ?? defaultValue) != "0"
  }

  @Test(.enabled(if: isSupportedPlatform))
  func callJavaMethodWithObjectArgument() throws {
    let environment = try JavaVirtualMachine.shared().environment()
    let receiver: JNITypes.jstring = try #require("hello".getJNIValue(in: environment))
    defer { environment.swiftInterface.DeleteLocalRef(environment, receiver) }
    let suffix: JNITypes.jstring = try #require(" world".getJNIValue(in: environment))
    defer { environment.swiftInterface.DeleteLocalRef(environment, suffix) }

    let javaClass: JNITypes.jclass = try #require(environment.swiftInterface.GetObjectClass(environment, receiver))
    defer { environment.swiftInterface.DeleteLocalRef(environment, javaClass) }
    let method = try #require(
      environment.swiftInterface.GetMethodID(environment, javaClass, "concat", "(Ljava/lang/String;)Ljava/lang/String;")
    )
    let arguments: [JNITypes.jvalue] = [JNITypes.objectValue(suffix)]
    let result = try #require(environment.swiftInterface.CallObjectMethodA(environment, receiver, method, arguments))
    defer { environment.swiftInterface.DeleteLocalRef(environment, result) }

    #expect(String(fromJNI: result, in: environment) == "hello world")
  }
}
