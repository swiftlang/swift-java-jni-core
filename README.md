# Swift Java JNI Core

The swift-java-jni-core package presents a *low-level* Swift-friendly interface to the Java Native Interface (JNI) specification, which is the universal set of data types and functions for interacting with a Java Virtual Machine and compatible derivatives, such as the Android Runtime (ART). You can view it as a thin layer on top of the `jni.h` along with pre-packaged type conversions and ways to interact with the JVM from Swift.

This package is designed to offer low-level zero-dependency support for higher-level modules, such as [SwiftJava](https://github.com/swiftlang/swift-java) and other projects.

> Most developers should prefer to use the [SwiftJava](https://github.com/swiftlang/swift-java) package for language interoperability. The `swift-java-jni-core` package exists solely for sharing low-level infrastructure.

## Swift Java Interoperability

Swift offers Java interoperability using the [SwiftJava](https://github.com/swiftlang/swift-java) package, package plugins, and also the `swift-java` command line tool for source generation (similar to OpenJDK jextract, if you are familiar with that concept). 

Most developers would benefit from using the SwiftJava package, as it features robust ways to make your interop code safe and performant, by using either source generation (`swift-java`) when calling Swift from Java, or Swift macros (`@JavaMethod`, ...) when calling Java from Swift. Multiple safeguards and optimizations are built into the SwiftJava library and we highly recommend using it instead of this low level "raw JNI" package.

## Swift Java JNI Core Features

### JavaValue

A `JavaValue` describes a type that can be bridged with Java. `JavaValue` is the base protocol for bridging between Swift types and their Java counterparts via the Java Native Interface (JNI). It is suitable for describing both value types (such as `Int32` or `Bool`) and object types.

### JavaVirtualMachine

The `JavaVirtualMachine` provides access to a Java Virtual Machine (JVM), which can either be loaded from within a Swift process (via `JNI_CreateJavaVM`), or accessed from a pre-existing in-process handle (`JNI_GetCreatedJavaVMs`). The JavaVirtualMachine is the entry point to interfacing with the JVM, and handles finding and loading classes, looking up and invoking methods, and handling details like locking, threads, and references.

### CSwiftJavaJNI

This C module provides the standardized and implementation-agnostic headers for the Java Native Interface [specification](http://java.sun.com/javase/6/docs/technotes/guides/jni/spec/jniTOC.html). The shape of these structures and symbols are guaranteed to be ABI stable between any compatible Java implementation.

## Contributing

Contributions are more than welcome, and you can read more about the process in [CONTRIBUTING.md](CONTRIBUTING.md).
