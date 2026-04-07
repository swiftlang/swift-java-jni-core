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
struct JavaEnvironmentTests {

  static var isSupportedPlatform: Bool {
    #if os(Android)
    let testSentinel = "0"
    #else
    let testSentinel = "1"
    #endif
    return (ProcessInfo.processInfo.environment["SWIFT_JAVA_JNI_TEST_JVM"] ?? testSentinel) != "0"
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFrame_returnsBodyValue() throws {
    let env = try JavaVirtualMachine.shared().environment()

    let result = try env.withLocalFrame(capacity: 4) {
      42
    }
    #expect(result == 42)
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFrame_defaultCapacity() throws {
    let env = try JavaVirtualMachine.shared().environment()

    let result = try env.withLocalFrame {
      "hello"
    }
    #expect(result == "hello")
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFrame_rethrowsErrors() throws {
    let env = try JavaVirtualMachine.shared().environment()

    struct TestError: Error {}

    #expect(throws: TestError.self) {
      try env.withLocalFrame {
        throw TestError()
      }
    }
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFrame_localRefsWorkInsideFrame() throws {
    let env = try JavaVirtualMachine.shared().environment()

    try env.withLocalFrame(capacity: 8) {
      // Create a local ref inside the frame — it should be valid here
      let cls = env.interface.FindClass(env, "java/lang/String")
      #expect(cls != nil, "Should be able to find java.lang.String inside frame")
    }
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFramePromotingResult_promotesObject() throws {
    let env = try JavaVirtualMachine.shared().environment()

    let promoted = try env.withLocalFramePromotingResult(capacity: 8) { () -> jobject? in
      // Create a Java String inside the frame
      let str = env.interface.NewStringUTF(env, "test")
      return str
    }

    // The promoted reference should still be valid in the outer frame
    #expect(promoted != nil, "Promoted reference should not be nil")

    // Verify it's a valid object by getting its class
    let cls = env.interface.GetObjectClass(env, promoted)
    #expect(cls != nil, "Promoted object should have a valid class")

    env.deleteLocalRef(promoted)
    env.deleteLocalRef(cls)
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFramePromotingResult_nilResult() throws {
    let env = try JavaVirtualMachine.shared().environment()

    let result = try env.withLocalFramePromotingResult {
      nil
    }
    #expect(result == nil)
  }

  @Test(.enabled(if: isSupportedPlatform))
  func withLocalFramePromotingResult_rethrowsErrors() throws {
    let env = try JavaVirtualMachine.shared().environment()

    struct TestError: Error {}

    #expect(throws: TestError.self) {
      try env.withLocalFramePromotingResult {
        throw TestError()
      }
    }
  }

  @Test(.enabled(if: isSupportedPlatform))
  func deleteLocalRef_nilIsSafe() throws {
    let env = try JavaVirtualMachine.shared().environment()

    // Should not crash
    env.deleteLocalRef(nil)
  }

  @Test(.enabled(if: isSupportedPlatform))
  func jniNewArray_nestedStringArray() throws {
    let env = try JavaVirtualMachine.shared().environment()

    // Use jniNewArray to create a String[][] — this is the function fixed by HEAD
    let makeOuter = [[String]].jniNewArray(in: env)
    let outer = makeOuter(env, 2)
    #expect(outer != nil)

    // Create inner String[] arrays via getJNIValue and store them
    let inner0 = ["hello", "world"].getJNIValue(in: env)
    let inner1 = ["foo"].getJNIValue(in: env)

    env.interface.SetObjectArrayElement(env, outer, 0, inner0)
    env.interface.SetObjectArrayElement(env, outer, 1, inner1)

    // Read back and verify structure
    let readInner0 = env.interface.GetObjectArrayElement(env, outer, 0)
    #expect(readInner0 != nil)
    #expect(env.interface.GetArrayLength(env, readInner0) == 2)

    let readInner1 = env.interface.GetObjectArrayElement(env, outer, 1)
    #expect(readInner1 != nil)
    #expect(env.interface.GetArrayLength(env, readInner1) == 1)
  }

  @Test(.enabled(if: isSupportedPlatform))
  func jniNewArray_tripleNestedStringArray() throws {
    let env = try JavaVirtualMachine.shared().environment()

    // String[][][]
    let makeOuter = [[[String]]].jniNewArray(in: env)
    let outer = makeOuter(env, 1)
    #expect(outer != nil)
  }

  @Test(.enabled(if: isSupportedPlatform))
  func getJNIValue_nestedStringArray() throws {
    let env = try JavaVirtualMachine.shared().environment()

    let jniValue = [["hello", "world"]].getJNIValue(in: env)
    #expect(jniValue != nil)

    let outerLen = env.interface.GetArrayLength(env, jniValue)
    #expect(outerLen == 1)

    // Verify inner elements are accessible
    let inner = env.interface.GetObjectArrayElement(env, jniValue, 0)
    #expect(inner != nil)
    #expect(env.interface.GetArrayLength(env, inner) == 2)
  }
}
