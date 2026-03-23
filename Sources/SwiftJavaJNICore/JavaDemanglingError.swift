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

/// Describes an error that can occur when demangling a Java name.
public struct JavaDemanglingError: Error, Sendable {
  /// The kind of demangling error.
  internal let kind: Kind

  internal init(kind: Kind) {
    self.kind = kind
  }

  /// This does not match the form of a Java mangled type name.
  public static func invalidMangledName(_ name: String) -> JavaDemanglingError {
    JavaDemanglingError(kind: .invalidMangledName(name))
  }

  /// Extra text after the mangled name.
  public static func extraText(_ text: String) -> JavaDemanglingError {
    JavaDemanglingError(kind: .extraText(text))
  }

  internal enum Kind: Equatable, Hashable, Sendable {
    /// This does not match the form of a Java mangled type name.
    case invalidMangledName(String)

    /// Extra text after the mangled name.
    case extraText(String)
  }
}
