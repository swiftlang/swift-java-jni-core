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

/// Errors originating from JNI environment operations.
public enum JNIError: Error {
  /// The JVM was unable to allocate memory for a local reference frame.
  ///
  /// This occurs when `PushLocalFrame` fails, typically because the JVM
  /// is running low on memory. The pending Java `OutOfMemoryError` is
  /// cleared before this error is thrown.
  ///
  /// - Parameter framePushCapacity: The requested frame capacity that failed.
  case outOfMemory(framePushCapacity: Int)
}
