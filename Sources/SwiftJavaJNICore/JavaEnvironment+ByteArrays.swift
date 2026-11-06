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

/// What to do with a primitive array's elements when releasing them.
///
/// See [Release<Type>ArrayElements](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#Release_PrimitiveType_ArrayElements_routines).
public enum JavaArrayReleaseMode: jint, Sendable {
  /// Copy changes back to the Java array (if the elements were a copy) and free the buffer.
  case copyBackAndRelease = 0
  /// Copy changes back to the Java array but keep the buffer (`JNI_COMMIT`).
  case copyBack = 1
  /// Free the buffer without copying changes back (`JNI_ABORT`).
  case discard = 2
}

extension UnsafeMutablePointer<JNIEnv?> {
  /// Runs `body` with direct access to the elements of a Java `byte[]`.
  ///
  /// The JVM may pin the array or hand out a copy; either way, `body` sees
  /// `array.length` bytes, and changes are written back according to
  /// `releaseMode`. Unlike converting through `[Int8]`, this doesn't copy into a
  /// Swift array first, which matters for large payloads such as `Data`.
  /// No other JNI calls should be made from `body`.
  public func withByteArrayElements<Result>(
    _ array: jbyteArray,
    releaseMode: JavaArrayReleaseMode = .discard,
    _ body: (UnsafeMutableBufferPointer<jbyte>) throws -> Result
  ) rethrows -> Result {
    let count = Int(interface.GetArrayLength(self, array))
    let elements = interface.GetByteArrayElements(self, array, nil)
    defer { interface.ReleaseByteArrayElements(self, array, elements, releaseMode.rawValue) }
    return try body(UnsafeMutableBufferPointer(start: elements, count: elements == nil ? 0 : count))
  }

  /// Creates a Java `byte[]` holding a copy of `bytes`, as a local reference.
  /// Returns `nil` if the JVM couldn't allocate the array (an `OutOfMemoryError` is then pending).
  public func newByteArray(_ bytes: UnsafeRawBufferPointer) -> jbyteArray? {
    guard let array = interface.NewByteArray(self, jsize(bytes.count)) else {
      return nil
    }
    if let base = bytes.baseAddress, !bytes.isEmpty {
      interface.SetByteArrayRegion(self, array, 0, jsize(bytes.count), base.assumingMemoryBound(to: jbyte.self))
    }
    return array
  }
}
