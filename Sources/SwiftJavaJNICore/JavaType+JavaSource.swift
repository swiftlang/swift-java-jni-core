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

extension JavaType {
  /// Form a Java type based on the name that is produced by
  /// java.lang.Class.getName(). This can be primitive types like "int",
  /// class types like "java.lang.String", or arrays thereof.
  public init(javaTypeName: String) throws {
    switch javaTypeName {
    case "boolean": self = .boolean
    case "byte": self = .byte
    case "char": self = .char
    case "short": self = .short
    case "int": self = .int
    case "long": self = .long
    case "float": self = .float
    case "double": self = .double
    case "void": self = .void

    case let name where name.starts(with: "["):
      self = try JavaType(mangledName: name)

    case let className:
      self = JavaType(className: className)
    }
  }
}

extension JavaType: CustomStringConvertible {
  /// Description of the Java type as it would appear in Java source.
  public var description: String {
    switch self {
    case .boolean: return "boolean"
    case .byte: return "byte"
    case .char: return "char"
    case .short: return "short"
    case .int: return "int"
    case .long: return "long"
    case .float: return "float"
    case .double: return "double"
    case .void: return "void"
    case .array(let elementType): return "\(elementType.description)[]"
    case .class(let package, let name, let typeParameters):
      let packageClause: String =
        if let package {
          "\(package)."
        } else {
          ""
        }
      let genericClause: String =
        if !typeParameters.isEmpty {
          "<\(typeParameters.map(\.description).joined(separator: ", "))>"
        } else {
          ""
        }
      return "\(packageClause)\(name)\(genericClause)"
    }
  }

  /// Returns the class name if this java type was a class,
  /// and nil otherwise.
  public var className: String? {
    switch self {
    case .class(_, let name, _):
      return name
    default:
      return nil
    }
  }

  /// Returns the fully qualified class name if this java type was a class,
  /// and nil otherwise.
  public var fullyQualifiedClassName: String? {
    switch self {
    case .class(.some(let package), let name, _):
      return "\(package).\(name)"
    case .class(nil, let name, _):
      return name
    default:
      return nil
    }
  }
}
