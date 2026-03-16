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

extension UnsafeMutablePointer<JNIEnv?> {

  /// Execute `body` inside a JNI local reference frame.
  ///
  /// All local references created inside `body` are freed when it returns.
  /// This prevents local reference table overflow when making many JNI calls
  /// (e.g., in loops or from non-JVM threads like Swift's cooperative pool).
  ///
  /// If `PushLocalFrame` fails (returns negative), `body` is still executed
  /// but without a frame — this avoids popping the wrong frame on error.
  ///
  /// - Parameter capacity: Hint for how many local refs will be created.
  ///   The JVM may allocate more if needed. Must be > 0.
  /// - Parameter body: The closure to execute inside the local frame.
  /// - Returns: The value returned by `body`.
  /// - Throws: Rethrows any error thrown by `body`.
  ///
  /// ## See Also
  /// - [JNI PushLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PushLocalFrame)
  /// - [JNI PopLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PopLocalFrame)
  @inline(__always)
  public func withLocalFrame<R>(capacity: Int = 16, _ body: () throws -> R) rethrows -> R {
    let pushed = self.interface.PushLocalFrame(self, Int32(capacity))
    if pushed != JNI_OK {
      // PushLocalFrame failed (OutOfMemoryError pending). Execute body without
      // a frame rather than popping the wrong frame in the defer.
      return try body()
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
  /// - Throws: Rethrows any error thrown by `body`.
  ///
  /// ## See Also
  /// - [JNI PushLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PushLocalFrame)
  /// - [JNI PopLocalFrame](https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/functions.html#PopLocalFrame)
  @inline(__always)
  public func withLocalFramePromotingResult(capacity: Int = 16, _ body: () throws -> jobject?) rethrows -> jobject? {
    let pushed = self.interface.PushLocalFrame(self, Int32(capacity))
    if pushed != JNI_OK {
      return try body()
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
