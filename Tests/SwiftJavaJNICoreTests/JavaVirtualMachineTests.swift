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

import Testing

@testable import SwiftJavaJNICore

#if canImport(FoundationEssentials)
import class FoundationEssentials.ProcessInfo
#else
import class Foundation.ProcessInfo
#endif
@Suite
struct JavaVirtualMachineTests {

  static var isSupportedPlatform: Bool {
    #if os(Android)
    // Android tests are not currently run within an .apk and so do not have any ambient JVM.
    // This can be overridden for a test harness that supports running within an .apk, like:
    // skip android test --apk --env SWIFT_JAVA_JNI_TEST_JVM=1
    let testSentinel = "0"
    #else
    // tests for every other platform should be run in an environment with Java available unless explicitly disabled
    let testSentinel = "1"
    #endif
    return (ProcessInfo.processInfo.environment["SWIFT_JAVA_JNI_TEST_JVM"] ?? testSentinel) != "0"
  }

  @Test(.enabled(if: isSupportedPlatform))
  func loadJVMAndCallMethod() throws {
    // Load or create a shared JVM instance
    let jvm = try JavaVirtualMachine.shared()

    // Get the JNI environment for the current thread
    let env = try jvm.environment()

    // Find java.lang.System
    let systemClass = env.interface.FindClass(env, "java/lang/System")
    #expect(systemClass != nil, "Failed to find java.lang.System")

    // Look up the static method currentTimeMillis()J
    let methodID = env.interface.GetStaticMethodID(
      env,
      systemClass,
      "currentTimeMillis",
      "()J"
    )
    #expect(methodID != nil, "Failed to find System.currentTimeMillis")

    // Call System.currentTimeMillis() — returns jlong
    let timeMillis = env.interface.CallStaticLongMethodA(
      env,
      systemClass,
      methodID,
      nil
    )
    #expect(timeMillis > 0, "Expected a positive timestamp, got \(timeMillis)")
  }
}
