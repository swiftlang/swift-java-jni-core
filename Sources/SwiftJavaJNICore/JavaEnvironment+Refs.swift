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

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Bionic)
import Bionic
#elseif canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
#endif

// ==== -------------------------------------------------------------------
// MARK: Local Frame Helpers

// Local references are valid for the duration of a native method call. They are
// freed automatically after the native method returns. Each local reference
// costs some amount of Java Virtual Machine resource. Programmers need to make
// sure that native methods do not excessively allocate local references.
// Although local references are automatically freed after the native method
// returns to Java, excessive allocation of local references may cause the VM to
// run out of memory during the execution of a native method.
//
// See: https://docs.oracle.com/en/java/javase/21/docs/specs/jni/functions.html#local-references

/// Whether to print JNI `OutOfMemoryError` stack traces to stderr.
///
/// Checked once on first OOM and cached. Set the environment variable
/// `SWIFT_JAVA_JNI_EXCEPTION_DESCRIBE_OOM` to `true` or `1` to enable.
private let describeOOMException: Bool = {
  guard let value = getenv("SWIFT_JAVA_JNI_EXCEPTION_DESCRIBE_OOM") else {
    return false
  }
  let str = String(cString: value).lowercased()
  return str == "1" || str == "true" || str == "yes"
}()

extension UnsafeMutablePointer<JNIEnv?> {

  /// Handle a `PushLocalFrame` failure by optionally describing the pending
  /// exception to stderr, clearing it, and throwing a Swift error.
  ///
  /// Must be called while the `OutOfMemoryError` is still pending (i.e.
  /// before `ExceptionClear`). `ExceptionDescribe` is safe to call with a
  /// pending exception — it prints the stack trace to stderr and does **not**
  /// clear the exception.
  @inline(__always)
  internal func throwPushLocalFrameOOM(capacity: Int) throws(JNIError) -> Never {
    if describeOOMException {
      // Print the pending OutOfMemoryError stack trace to stderr.
      // ExceptionDescribe does not clear the exception.
      self.interface.ExceptionDescribe(self)
    }
    self.interface.ExceptionClear(self)
    throw JNIError.outOfMemory(framePushCapacity: capacity)
  }

  /// Execute `body` inside a JNI local reference frame.
  ///
  /// All local references created inside `body` are freed when it returns.
  /// This prevents local reference table overflow when making many JNI calls
  /// (e.g., in loops or from non-JVM threads like Swift's cooperative pool).
  ///
  /// - Parameter capacity: Hint for how many local refs will be created.
  ///   The JVM may allocate more if needed. Must be > 0.
  /// - Parameter body: The closure to execute inside the local frame.
  /// - Returns: The value returned by `body`.
  /// - Throws: ``JNIError/outOfMemory`` if `PushLocalFrame` fails, or
  ///   rethrows any error thrown by `body`.
  ///
  /// ## See Also
  /// - [JNI PushLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PushLocalFrame)
  /// - [JNI PopLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PopLocalFrame)
  @inline(__always)
  public func withLocalFrame<R>(capacity: Int = 16, _ body: () throws -> R) throws -> R {
    let pushed = self.interface.PushLocalFrame(self, Int32(capacity))
    if pushed != JNI_OK {
      try self.throwPushLocalFrameOOM(capacity: capacity)
    }
    defer { _ = self.interface.PopLocalFrame(self, nil) }
    return try body()
  }

  /// Execute `body` inside a JNI local reference frame, promoting one result
  /// object to the outer frame.
  ///
  /// All local references created inside `body` are freed, **except** for the
  /// returned `jobject` which is promoted to the enclosing frame via
  /// `PopLocalFrame(env, result)`.
  ///
  /// Use this when constructing a new Java object inside a frame that needs
  /// to survive after the frame is popped.
  ///
  /// - Parameter capacity: Hint for how many local refs will be created.
  /// - Parameter body: Closure that returns the `jobject` to promote.
  /// - Returns: A new local reference in the outer frame to the same object.
  /// - Throws: ``JNIError/outOfMemory`` if `PushLocalFrame` fails, or
  ///   rethrows any error thrown by `body`.
  ///
  /// ## See Also
  /// - [JNI PushLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PushLocalFrame)
  /// - [JNI PopLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PopLocalFrame)
  @inline(__always)
  public func withLocalFramePromotingResult(capacity: Int = 16, _ body: () throws -> jobject?) throws -> jobject? {
    let pushed = self.interface.PushLocalFrame(self, Int32(capacity))
    if pushed != JNI_OK {
      try self.throwPushLocalFrameOOM(capacity: capacity)
    }
    do {
      let result = try body()
      return self.interface.PopLocalFrame(self, result)
    } catch {
      // Pop the frame (freeing all inner refs) before rethrowing.
      _ = self.interface.PopLocalFrame(self, nil)
      throw error
    }
  }

  /// Delete a local reference.
  ///
  /// Shorthand for `interface.DeleteLocalRef(self, ref)`. Safe to call with
  /// `nil` (no-op).
  ///
  /// ## See Also
  /// - [JNI DeleteLocalRef](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#DeleteLocalRef)
  @inline(__always)
  public func deleteLocalRef(_ ref: jobject?) {
    self.interface.DeleteLocalRef(self, ref)
  }
}
