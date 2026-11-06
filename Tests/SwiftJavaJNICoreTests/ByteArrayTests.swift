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

@Suite
struct ByteArrayTests {

  @Test(.enabled(if: JavaVirtualMachineTests.isSupportedPlatform), arguments: [0, 1, 5, 64 * 1024])
  func roundTrip(count: Int) throws {
    let env = try JavaVirtualMachine.shared().environment()
    let bytes = (0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31) }
    let array = try #require(bytes.withUnsafeBytes { env.newByteArray($0) })
    defer { env.interface.DeleteLocalRef(env, array) }
    #expect(env.interface.GetArrayLength(env, array) == jsize(count))

    let read = env.withByteArrayElements(array) { Array(UnsafeRawBufferPointer($0)) }
    #expect(read == bytes)
  }

  @Test(.enabled(if: JavaVirtualMachineTests.isSupportedPlatform))
  func releaseModesControlWriteBack() throws {
    let env = try JavaVirtualMachine.shared().environment()
    let array = try #require([UInt8](repeating: 0, count: 4).withUnsafeBytes { env.newByteArray($0) })
    defer { env.interface.DeleteLocalRef(env, array) }

    env.withByteArrayElements(array, releaseMode: .copyBackAndRelease) { $0[0] = 7 }
    env.withByteArrayElements(array, releaseMode: .discard) { $0[1] = 9 } // dropped if the JVM gave us a copy

    var region = [jbyte](repeating: 0, count: 4)
    env.interface.GetByteArrayRegion(env, array, 0, 4, &region)
    #expect(region[0] == 7)
  }
}
