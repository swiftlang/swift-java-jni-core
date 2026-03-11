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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

#if canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

public typealias JavaVMPointer = UnsafeMutablePointer<JavaVM?>
typealias JNIEnvPointer = UnsafeMutablePointer<JNIEnv?>

extension FileManager {
  #if os(Windows)
  static let pathSeparator = ";"
  #else
  static let pathSeparator = ":"
  #endif

  #if os(Windows)
  static let libraryExtension = "dll"
  #elseif canImport(Darwin)
  static let libraryExtension = "dylib"
  #else
  static let libraryExtension = "so"
  #endif
}

public final class JavaVirtualMachine: @unchecked Sendable {
  /// The JNI version that we depend on.
  static let jniVersion = JNI_VERSION_1_6

  /// Thread-local storage to detach from thread on exit
  private static let destroyTLS = ThreadLocalStorage { _ in
    try? JavaVirtualMachine.shared().detachCurrentThread()
  }

  /// The Java virtual machine instance.
  private let jvm: JavaVMPointer

  let classpath: [String]

  /// Whether to destroy the JVM on deinit.
  private let destroyOnDeinit: LockedState<Bool> // FIXME: we should require macOS 15 and then use Synchronization

  /// Adopt an existing JVM pointer.
  public init(adoptingJVM jvm: JavaVMPointer) {
    self.jvm = jvm
    self.classpath = [] // FIXME: bad...
    self.destroyOnDeinit = .init(initialState: false)
  }

  /// Initialize a new Java virtual machine instance.
  ///
  /// - Parameters:
  ///   - classpath: The directories, JAR files, and ZIP files in which the JVM
  ///     should look to find classes. This maps to the VM option
  ///     `-Djava.class.path=`.
  ///   - vmOptions: Options that should be passed along to the JVM, which will
  ///     be prefixed by the class-path argument described above.
  ///   - ignoreUnrecognized: Whether the JVM should ignore any VM options it
  ///     does not recognize.
  private init(
    classpath: [String] = [],
    vmOptions: [String] = [],
    ignoreUnrecognized: Bool = false
  ) throws {
    self.classpath = classpath
    var jvm: JavaVMPointer? = nil
    var environment: JNIEnvPointer? = nil
    var vmArgs = JavaVMInitArgs()
    vmArgs.version = JavaVirtualMachine.jniVersion
    vmArgs.ignoreUnrecognized = jboolean(ignoreUnrecognized ? JNI_TRUE : JNI_FALSE)

    // Construct the complete list of VM options.
    var allVMOptions: [String] = []
    if !classpath.isEmpty {
      let fileManager = FileManager.default
      for path in classpath {
        if !fileManager.fileExists(atPath: path) {
          // FIXME: this should be configurable, a classpath missing a directory isn't reason to blow up
          print(
            "[warning][swift-java][JavaVirtualMachine] Missing classpath element: \(URL(fileURLWithPath: path).absoluteString)"
          ) // TODO: stderr
        }
      }
      let pathSeparatedClassPath = classpath.joined(separator: FileManager.pathSeparator)
      allVMOptions.append("-Djava.class.path=\(pathSeparatedClassPath)")
    }
    allVMOptions.append(contentsOf: vmOptions)

    // Convert the options
    let optionsBuffer = UnsafeMutableBufferPointer<JavaVMOption>.allocate(capacity: allVMOptions.count)
    defer {
      optionsBuffer.deallocate()
    }
    for (index, vmOption) in allVMOptions.enumerated() {
      let optionString = vmOption.utf8CString.withUnsafeBufferPointer { buffer in
        let cString = UnsafeMutableBufferPointer<CChar>.allocate(capacity: buffer.count + 1)
        _ = cString.initialize(from: buffer)
        cString[buffer.count] = 0
        return cString
      }
      optionsBuffer[index] = JavaVMOption(optionString: optionString.baseAddress, extraInfo: nil)
    }
    defer {
      for option in optionsBuffer {
        option.optionString.deallocate()
      }
    }
    vmArgs.options = optionsBuffer.baseAddress
    vmArgs.nOptions = jint(optionsBuffer.count)

    typealias CreateJavaVM = @convention(c) (_ pvm: UnsafeMutablePointer<JavaVMPointer?>?, _ penv: UnsafeMutablePointer<JNIEnvPointer?>?, _ args: UnsafeMutableRawPointer) -> jint
    guard let createJavaVM = dlsym(try Self.loadLibJava(), "JNI_CreateJavaVM").map({ unsafeBitCast($0, to: (CreateJavaVM).self) }) else {
      throw VMError.cannotLoadCreateJavaVM
    }

    // Create the JVM instance.
    if let createError = VMError(fromJNIError: createJavaVM(&jvm, &environment, &vmArgs)) {
      throw createError
    }

    self.jvm = jvm!
    self.destroyOnDeinit = .init(initialState: true)
  }

  public func destroyJVM() throws {
    try self.detachCurrentThread()
    if let error = VMError(fromJNIError: jvm.pointee!.pointee.DestroyJavaVM(jvm)) {
      throw error
    }

    destroyOnDeinit.withLock { $0 = false } // we destroyed explicitly, disable destroy in deinit
  }

  deinit {
    if destroyOnDeinit.withLock({ $0 }) {
      do {
        try destroyJVM()
      } catch {
        fatalError("Failed to destroy the JVM: \(error)")
      }
    }
  }
}

extension JavaVirtualMachine: CustomStringConvertible {
  public var description: String {
    "\(Self.self)(\(jvm))"
  }
}

// ==== ------------------------------------------------------------------------
// MARK: Java thread management.

extension JavaVirtualMachine {
  /// Produce the JNI environment for the active thread, attaching this
  /// thread to the JVM if it isn't already.
  ///
  /// - Parameter
  ///   - asDaemon: Whether this thread should be treated as a daemon
  ///     thread in the Java Virtual Machine.
  public func environment(asDaemon: Bool = false) throws -> JNIEnvironment {
    // Check whether this thread is already attached. If so, return the
    // corresponding environment.
    var environment: UnsafeMutableRawPointer? = nil
    let getEnvResult = jvm.pointee!.pointee.GetEnv(
      jvm,
      &environment,
      JavaVirtualMachine.jniVersion
    )
    if getEnvResult == JNI_OK, let environment {
      return environment.assumingMemoryBound(to: JNIEnv?.self)
    }

    var jniEnv = environment?.assumingMemoryBound(to: JNIEnv?.self)

    // Attach the current thread to the JVM.
    let attachResult: jint
    if asDaemon {
      attachResult = jvm.pointee!.pointee.AttachCurrentThreadAsDaemon(jvm, &jniEnv, nil)
    } else {
      attachResult = jvm.pointee!.pointee.AttachCurrentThread(jvm, &jniEnv, nil)
    }

    // If we failed to attach, report that.
    if let attachError = VMError(fromJNIError: attachResult) {
      // throw attachError
      fatalError("JVM Error: \(attachError)")
    }

    JavaVirtualMachine.destroyTLS.set(jniEnv!)

    return jniEnv!
  }

  /// Detach the current thread from the Java Virtual Machine. All Java
  /// threads waiting for this thread to die are notified.
  func detachCurrentThread() throws {
    if let resultError = VMError(fromJNIError: jvm.pointee!.pointee.DetachCurrentThread(jvm)) {
      throw resultError
    }
  }
}
// ==== ------------------------------------------------------------------------
// MARK: Shared Java Virtual Machine management.

extension JavaVirtualMachine {
  /// The globally shared JavaVirtualMachine instance, behind a lock.
  ///
  /// TODO: If the use of the lock itself ends up being slow, we could
  /// use an atomic here instead because our access pattern is fairly
  /// simple.
  static let sharedJVM: LockedState<JavaVirtualMachine?> = .init(initialState: nil)

  /// Set the shared Java Virtual Machine instance.
  ///
  /// This is used by higher-level modules (e.g. SwiftJava) to register
  /// a JVM that was created or adopted externally.
  public static func setSharedJVM(_ jvm: JavaVirtualMachine) {
    sharedJVM.withLock { $0 = jvm }
  }

  /// Access the shared Java Virtual Machine instance.
  ///
  /// If there is no shared Java Virtual Machine, create one with the given
  /// arguments. Note that this function makes no attempt to try to augment
  /// an existing virtual machine instance with the options given, so it is
  /// up to clients to ensure that consistent arguments are provided to all
  /// calls.
  ///
  /// - Parameters:
  ///   - classpath: The directories, JAR files, and ZIP files in which the JVM
  ///     should look to find classes. This maps to the VM option
  ///     `-Djava.class.path=`.
  ///   - vmOptions: Options that should be passed along to the JVM, which will
  ///     be prefixed by the class-path argument described above.
  ///   - ignoreUnrecognized: Whether the JVM should ignore any VM options it
  ///     does not recognize.
  ///   - replace: replace the existing shared JVM instance
  public static func shared(
    classpath: [String] = [],
    vmOptions: [String] = [],
    ignoreUnrecognized: Bool = false,
    replace: Bool = false
  ) throws -> JavaVirtualMachine {
    precondition(
      !classpath.contains(where: { $0.contains(FileManager.pathSeparator) }),
      "Classpath element must not contain `\(FileManager.pathSeparator)`! Split the path into elements! Was: \(classpath)"
    )

    return try sharedJVM.withLock { (sharedJVMPointer: inout JavaVirtualMachine?) in
      // If we already have a JavaVirtualMachine instance, return it.
      if replace {
        print("[swift-java] Replace JVM instance!")
        try sharedJVMPointer?.destroyJVM()
        sharedJVMPointer = nil
      } else {
        if let existingInstance = sharedJVMPointer {
          // FIXME: this isn't ideal; we silently ignored that we may have requested a different classpath or options
          return existingInstance
        }
      }

      typealias GetCreatedJavaVMs = @convention(c) (_ pvm: UnsafeMutablePointer<JavaVMPointer?>, _ count: Int32, _ num: UnsafeMutablePointer<Int32>) -> jint
      guard let getCreatedJavaVMs = dlsym(try loadLibJava(), "JNI_GetCreatedJavaVMs").map({ unsafeBitCast($0, to: (GetCreatedJavaVMs).self) }) else {
        throw VMError.cannotLoadGetCreatedJavaVMs
      }

      while true {
        var wasExistingVM: Bool = false
        while true {
          // Query the JVM itself to determine whether there is a JVM
          // instance that we don't yet know about.
          var jvm: JavaVMPointer? = nil
          var numJVMs: jsize = 0
          if getCreatedJavaVMs(&jvm, 1, &numJVMs) == JNI_OK, numJVMs >= 1 {
            // Adopt this JVM into a new instance of the JavaVirtualMachine
            // wrapper.
            let javaVirtualMachine = JavaVirtualMachine(adoptingJVM: jvm!)
            sharedJVMPointer = javaVirtualMachine
            return javaVirtualMachine
          }

          precondition(
            !wasExistingVM,
            "JVM reports that an instance of the JVM was already created, but we didn't see it."
          )

          // Create a new instance of the JVM.
          let javaVirtualMachine: JavaVirtualMachine
          do {
            javaVirtualMachine = try JavaVirtualMachine(
              classpath: classpath,
              vmOptions: vmOptions,
              ignoreUnrecognized: ignoreUnrecognized
            )
          } catch VMError.existingVM {
            // We raced with code outside of this JavaVirtualMachine instance
            // that created a VM while we were trying to do the same. Go
            // through the loop again to pick up the underlying JVM pointer.
            wasExistingVM = true
            continue
          }

          sharedJVMPointer = javaVirtualMachine
          return javaVirtualMachine
        }
      }
    }
  }

  /// Located the shared library that includes the `JNI_GetCreatedJavaVMs` and `JNI_CreateJavaVM` entry points to the `JNINativeInterface` function table
  private static func loadLibJava() throws -> UnsafeMutableRawPointer {
    #if os(Android)
    for libname in ["libart.so", "libdvm.so", "libnativehelper.so"] {
      if let lib = dlopen(libname, RTLD_NOW) {
        return lib
      }
    }
    #endif

    guard let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"] ?? {
      // if JAVA_HOME is unset, look in some standard locations
      [
        "/opt/homebrew/opt/java", // macOS Homebrew
        "/usr/local/opt/java",
        "/usr/lib/jvm/default-java", // Ubuntu/Debian
        "/usr/lib/jvm/default", // Arch
      ].first(where: {
        FileManager.default.fileExists(atPath: $0)
      })
    }() else {
      throw VMError.javaHomeNotFound
    }

    let javaHomeURL = URL(fileURLWithPath: javaHome, isDirectory: true)

    let ext = FileManager.libraryExtension
    let libjvmPaths = [
      URL(fileURLWithPath: "jre/lib/server/libjvm.\(ext)", relativeTo: javaHomeURL),
      URL(fileURLWithPath: "lib/server/libjvm.\(ext)", relativeTo: javaHomeURL),
      URL(fileURLWithPath: "lib/libjvm.\(ext)", relativeTo: javaHomeURL),
      URL(fileURLWithPath: "libexec/openjdk.jdk/Contents/Home/lib/server/libjvm.\(ext)", relativeTo: javaHomeURL),
    ]

    guard let libjvmPath = libjvmPaths.first(where: {
      FileManager.default.isReadableFile(atPath: $0.path)
    }) else {
      throw VMError.libjvmNotFound
    }

    guard let dylib = dlopen(libjvmPath.path, RTLD_NOW) else {
      throw VMError.libjvmNotLoaded
    }

    return dylib
  }

  /// "Forget" the shared JavaVirtualMachine instance.
  ///
  /// This will allow the shared JavaVirtualMachine instance to be deallocated.
  public static func forgetShared() {
    sharedJVM.withLock { sharedJVMPointer in
      sharedJVMPointer = nil
    }
  }

  /// Set the shared JavaVirtualMachine instance.
  ///
  /// This is used by `JNI_OnLoad` to register the JVM instance
  /// when loaded as a dynamic library by Java.
  public static func setShared(_ javaVM: JavaVirtualMachine) {
    sharedJVM.withLock { $0 = javaVM }
  }
}

extension JavaVirtualMachine {
  /// Describes the kinds of errors that can occur when interacting with JNI.
  enum VMError: Error {
    /// There is already a Java Virtual Machine.
    case existingVM

    /// JNI version mismatch error.
    case jniVersion

    /// Thread is detached from the VM.
    case threadDetached

    /// Out of memory.
    case outOfMemory

    /// Invalid arguments.
    case invalidArguments

    /// Cannot locate a `JAVA_HOME`
    case javaHomeNotFound

    /// Cannot find `libjvm`
    case libjvmNotFound

    /// Cannot `dlopen` `libjvm`
    case libjvmNotLoaded

    /// Cannot load `JNI_GetCreatedJavaVMs` from `libjvm`
    case cannotLoadGetCreatedJavaVMs

    /// Cannot load `JNI_CreateJavaVM` from `libjvm`
    case cannotLoadCreateJavaVM

    /// Unknown JNI error.
    case unknown(jint, file: String, line: UInt)

    init?(fromJNIError error: jint, file: String = #fileID, line: UInt = #line) {
      switch error {
      case JNI_OK: return nil
      case JNI_EDETACHED: self = .threadDetached
      case JNI_EVERSION: self = .jniVersion
      case JNI_ENOMEM: self = .outOfMemory
      case JNI_EEXIST: self = .existingVM
      case JNI_EINVAL: self = .invalidArguments
      default: self = .unknown(error, file: file, line: line)
      }
    }
  }

  enum JavaKitError: Error {
    case classpathEntryNotFound(entry: String, classpath: [String])
  }
}
