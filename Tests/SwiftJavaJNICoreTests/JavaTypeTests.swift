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

@Suite
struct JavaTypeTests {
  @Test(
    arguments: [
      (.int, "int"),
      (.array(.long), "long[]"),
      (.char(parameterAnnotations: [.unsigned]), "char"),
      (
        .class(
          package: nil,
          name: "Tuple",
          typeParameters: [.class(package: nil, name: "Integer"), .class(package: nil, name: "String")]
        ),
        "Tuple<Integer, String>"
      ),
      (
        .class(
          package: "java.util",
          name: "List",
          typeParameters: [.class(package: "java.lang", name: "String")]
        ),
        "java.util.List<java.lang.String>"
      ),
    ] as [(JavaType, String)]
  )
  func description(javaType: JavaType, expected: String) throws {
    #expect(javaType.description == expected)
  }
}
