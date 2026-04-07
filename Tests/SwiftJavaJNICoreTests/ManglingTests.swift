//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
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

@Suite
struct ManglingTests {

  @Test
  func methodMangling() throws {
    let demangledSignature = try MethodSignature(
      mangledName: "(ILjava/lang/String;[I)J"
    )
    let expectedSignature = MethodSignature(
      resultType: .long,
      parameterTypes: [
        .int,
        .class(package: "java.lang", name: "String"),
        .array(.int),
      ]
    )
    #expect(demangledSignature == expectedSignature)
    #expect(expectedSignature.mangledName == "(ILjava/lang/String;[I)J")
  }

  // Nested arrays

  @Test(
    arguments: [
      // Primitive arrays
      (.array(.int), "[I"),
      (.array(.long), "[J"),
      (.array(.byte), "[B"),
      (.array(.boolean), "[Z"),
      (.array(.double), "[D"),

      // Object arrays
      (.array(.class(package: "java.lang", name: "String")), "[Ljava/lang/String;"),

      // Nested arrays (the fix in jniNewArray relies on these mangled names)
      (.array(.array(.int)), "[[I"),
      (.array(.array(.long)), "[[J"),
      (.array(.array(.class(package: "java.lang", name: "String"))), "[[Ljava/lang/String;"),
      (.array(.array(.array(.int))), "[[[I"),
    ] as [(JavaType, String)]
  )
  func arrayMangling(javaType: JavaType, expectedMangledName: String) throws {
    #expect(javaType.mangledName == expectedMangledName)
    let roundTripped = try JavaType(mangledName: expectedMangledName)
    #expect(roundTripped == javaType)
  }

  @Test
  func nestedArrayElementMangledName() throws {
    let nestedIntArray = JavaType.array(.array(.int))
    let elementType =
      switch nestedIntArray {
      case .array(let element): element
      default: fatalError("expected array type")
      }
    #expect(elementType.mangledName == "[I")

    let nestedStringArray = JavaType.array(.array(.class(package: "java.lang", name: "String")))
    let stringElementType =
      switch nestedStringArray {
      case .array(let element): element
      default: fatalError("expected array type")
      }
    #expect(stringElementType.mangledName == "[Ljava/lang/String;")
  }

  @Test(
    arguments: [
      // Class types: FindClass needs "java/lang/String", not "Ljava/lang/String;"
      (.class(package: "java.lang", name: "String"), "java/lang/String"),
      (.class(package: "java.util", name: "List"), "java/util/List"),

      // Array types: FindClass accepts the full type descriptor
      (.array(.class(package: "java.lang", name: "String")), "[Ljava/lang/String;"),
      (.array(.int), "[I"),
      (.array(.array(.class(package: "java.lang", name: "String"))), "[[Ljava/lang/String;"),

      // Primitives (not typically used with FindClass, but should return mangledName)
      (.int, "I"),
      (.boolean, "Z"),
    ] as [(JavaType, String)]
  )
  func jniFindClassName(javaType: JavaType, expected: String) {
    #expect(javaType.jniFindClassName == expected)
  }
}
