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
struct JavaStringTests {

  static let samples = [
    "",
    "hello",
    "héllo",
    "日本語",
    "🎵🎶",
    "A🎵B",
    "Fed 🇺🇸 📉",
    "before\0after",
  ]

  @Test(.enabled(if: JavaEnvironmentTests.isSupportedPlatform), arguments: samples)
  func roundTrip(_ string: String) throws {
    let env = try JavaVirtualMachine.shared().environment()

    try env.withLocalFrame {
      let javaString = string.getJNIValue(in: env)
      #expect(String(fromJNI: javaString, in: env) == string)
    }
  }

  @Test(.enabled(if: JavaEnvironmentTests.isSupportedPlatform), arguments: samples)
  func javaLengthMatchesUTF16(_ string: String) throws {
    let env = try JavaVirtualMachine.shared().environment()

    try env.withLocalFrame {
      let javaString = string.getJNIValue(in: env)
      #expect(env.interface.GetStringLength(env, javaString) == Int32(string.utf16.count))
    }
  }
}
