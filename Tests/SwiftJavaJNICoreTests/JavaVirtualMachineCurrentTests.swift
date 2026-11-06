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

#if canImport(Dispatch)
import Dispatch
#endif

@Suite
struct JavaVirtualMachineCurrentTests {

  @Test(.enabled(if: JavaVirtualMachineTests.isSupportedPlatform))
  func currentMatchesShared() throws {
    let shared = try JavaVirtualMachine.shared()
    let current = try #require(JavaVirtualMachine.current)
    #expect(current === shared)
    #expect(try JavaVirtualMachine.shared() === shared, "shared() must keep returning the published instance")

    // `current` is usable for JNI work on its own.
    let env = try current.environment()
    #expect(env.interface.FindClass(env, "java/lang/Object") != nil)
  }

  #if canImport(Dispatch)
  @Test(.enabled(if: JavaVirtualMachineTests.isSupportedPlatform))
  func concurrentReadsSeeOneInstance() throws {
    let shared = try JavaVirtualMachine.shared()
    let mismatches = LockedState(initialState: 0)
    DispatchQueue.concurrentPerform(iterations: 8) { _ in
      var local = 0
      for _ in 0..<100_000 where JavaVirtualMachine.current !== shared {
        local += 1
      }
      let count = local
      mismatches.withLock { $0 += count }
    }
    #expect(mismatches.withLock { $0 } == 0)
  }
  #endif

  /// Not an assertion on timing (CI machines vary); prints the cost of the lock-free read
  /// next to the locked read that `shared()` used to take on every call.
  @Test(.enabled(if: JavaVirtualMachineTests.isSupportedPlatform))
  func currentIsCheaperThanLockedRead() throws {
    _ = try JavaVirtualMachine.shared()
    let iterations = 2_000_000

    func measure(_ body: () -> Bool) -> Double {
      var hits = 0
      let start = ContinuousClock.now
      for _ in 0..<iterations where body() {
        hits += 1
      }
      let elapsed = ContinuousClock.now - start
      #expect(hits == iterations)
      let (seconds, attoseconds) = elapsed.components
      return (Double(seconds) * 1e9 + Double(attoseconds) / 1e9) / Double(iterations)
    }

    let lockFree = measure { JavaVirtualMachine.current != nil }
    let locked = measure { JavaVirtualMachine.sharedJVM.withLock { $0 } != nil }
    print("JavaVirtualMachine.current: \(lockFree) ns/op; locked read: \(locked) ns/op")
  }
}
