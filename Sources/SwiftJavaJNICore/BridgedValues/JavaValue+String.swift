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


extension String: JavaValue {
  public typealias JNIType = jstring?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType {
    .class(package: "java.lang", name: "String")
  }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    guard let value else {
      self.init()
      return
    }
    let cString = environment.interface.GetStringUTFChars(environment, value, nil)!
    defer { environment.interface.ReleaseStringUTFChars(environment, value, cString) }
    if let string = String(validatingCString: cString) {
      self = string
      return
    }
    // GetStringUTFChars returns "modified UTF-8", which encodes NUL as 0xC0 0x80 and, on
    // HotSpot, characters outside the BMP as surrogate pairs; neither is valid UTF-8.
    let length = environment.interface.GetStringLength(environment, value)
    self = withUnsafeTemporaryAllocation(of: UInt16.self, capacity: Int(length)) { buffer in
      environment.interface.GetStringRegion(environment, value, 0, length, buffer.baseAddress)
      return String(decoding: buffer, as: UTF16.self)
    }
  }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    // NewStringUTF takes "modified UTF-8", which matches UTF-8 unless the string has a NUL
    // or a character outside the BMP (a 4-byte sequence); those go through UTF-16 instead.
    let isModifiedUTF8 = utf8.withContiguousStorageIfAvailable { bytes in
      !bytes.contains { $0 == 0 || $0 >= 0xF0 }
    }
    if isModifiedUTF8 == true {
      return withCString { environment.interface.NewStringUTF(environment, $0) }
    }
    var utfBuffer = Array(utf16)
    return environment.interface.NewString(environment, &utfBuffer, Int32(utfBuffer.count))
  }

  public static func jniMethodCall(in environment: JNIEnvironment) -> JNIMethodCall<JNIType> {
    environment.interface.CallObjectMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetObjectField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetObjectField
  }

  public static func jniStaticMethodCall(in environment: JNIEnvironment) -> JNIStaticMethodCall<JNIType> {
    environment.interface.CallStaticObjectMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticObjectField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticObjectField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    { environment, size in
      // FIXME: Introduce a JavaString class that we can use for this.
      let stringClass = environment.interface.FindClass(environment, "java/lang/String")
      return environment.interface.NewObjectArray(environment, size, stringClass, nil)
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    { environment, array, start, length, outPointer in
      let buffer = UnsafeMutableBufferPointer(start: outPointer, count: Int(length))
      for i in 0..<length {
        buffer.initializeElement(
          at: Int(i),
          to: environment.interface.GetObjectArrayElement(environment, array, Int32(start + i))
        )
      }
    }
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    { environment, array, start, length, outPointer in
      let buffer = UnsafeBufferPointer(start: outPointer, count: Int(length))
      for i in start..<start + length {
        environment.interface.SetObjectArrayElement(environment, array, i, buffer[Int(i)])
      }
    }
  }

  public static var jniPlaceholderValue: jstring? {
    nil
  }
}
