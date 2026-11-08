# Swift Operation Context

[![Documentation](https://img.shields.io/badge/docc-read_documentation-blue)](https://swiftpackageindex.com/swift-microservices/swift-operation-context/documentation)
[![Release](https://img.shields.io/github/v/release/swift-microservices/swift-operation-context)](https://github.com/swift-microservices/swift-operation-context/releases)
[![Swift versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fswift-microservices%2Fswift-operation-context%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/swift-microservices/swift-operation-context)
[![CI](https://github.com/swift-microservices/swift-operation-context/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/swift-microservices/swift-operation-context/actions/workflows/ci.yml)

`OperationContext` is a lightweight container for passing typed values through a request, a job,
or any other unit of work, without threading them through every function signature. Libraries can
use it to carry identity, credentials, or database settings without depending on each other's
domain types.

- 🚀 Typed, task-scoped values built on Swift concurrency's task-local values
- 📦 Zero dependencies and no Foundation import; one product, `OperationContext`
- 🧱 The foundation every other `swift-microservices` package builds on
- 📱 Supports Linux (including the static SDK) and macOS 15+
- 🔧 Built with Swift 6.3+ in Swift 6 language mode

🔗 Jump to:
- 📖 [Overview](#-overview)
- 🏁 [Getting Started](#-getting-started)
- 📘 [Documentation](#-documentation)
- 🧰 [Release Info](#-release-info)
- 🛠️ [Support](#%EF%B8%8F-support)

## 📖 Overview

A request handler often learns something early — who the caller is, which tenant they belong to,
which database settings apply — that code several calls and tasks deeper needs to know. Instead of
adding a parameter to every function in between, you put the value in an `OperationContext`, bind
it for the scope of the work, and read it back with `OperationContext.current` wherever it's
needed, including in child tasks.

Each value is stored under a key type you define, so libraries can share one context without
knowing about each other. Start with an empty `OperationContext()` for a new operation, or copy
`OperationContext.current` to extend an existing one.

**Key Features:**
- 🔑 **Typed keys**: Each key conforms to `OperationContextKey` and names a `Sendable` value type.
  Keys are identified by their type, so two keys with the same value type never collide.
- 📍 **Scoped binding**: `withContext(_:operation:)` makes a context current for one operation and
  restores the previous binding when the operation returns or throws. Synchronous and asynchronous
  overloads are provided.
- 🧬 **Value semantics**: The context is a value type; changing a copy leaves the original
  unchanged. Stored reference values keep their own sharing semantics and are not deep-copied.
- ⚡ **Swift concurrency**: Structured child tasks inherit the bound context. The asynchronous
  overload keeps the caller's actor isolation and runs in the existing task.
- 🧩 **No domain coupling**: The package only propagates values. Authentication, authorization,
  and database policy enforcement belong to the libraries that define the keys.

## 🏁 Getting Started

### Prerequisites

- Swift version: Swift 6.3+
- Platforms: Linux, and macOS 15 or later

To install/upgrade Swift, see https://www.swift.org/install/

### Adding as a dependency

Add the package to your `Package.swift`, then add the `OperationContext` product to your target:

```swift
dependencies: [
    .package(url: "https://github.com/swift-microservices/swift-operation-context.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyLibrary",
        dependencies: [
            .product(name: "OperationContext", package: "swift-operation-context")
        ]
    )
]
```

### Usage

Define a key, bind a value for a scope of work, and read it from child tasks:

```swift
import OperationContext

// 1. Define a key. Its type identifies the entry; `Value` is what it stores.
enum TenantIDKey: OperationContextKey {
    typealias Value = String
}

// 2. Read the value anywhere inside the scope. An unset key reads as `nil`.
func audit(_ action: String) async -> String {
    let tenantID = OperationContext.current[TenantIDKey.self] ?? "none"
    return "\(tenantID): \(action)"
}

// 3. Bind a value for one scope of work.
var context = OperationContext()
context[TenantIDKey.self] = "tenant-123"

let lines = await OperationContext.withContext(context) {
    // Child tasks created with `async let` or a task group inherit the context.
    async let invoices = audit("load invoices")
    async let orders = audit("load orders")
    return await [invoices, orders]
}

assert(lines == ["tenant-123: load invoices", "tenant-123: load orders"])

// Outside the scope, the previous binding is back. `current` defaults to an empty context.
assert(OperationContext.current[TenantIDKey.self] == nil)
```

#### Extend the current context

`withContext` replaces the whole binding for its scope; contexts are never merged. To keep the
values an enclosing scope set, copy `current`, change the copy, and bind that:

```swift
OperationContext.withContext(context) {
    var nested = OperationContext.current
    nested[TenantIDKey.self] = "tenant-456"

    OperationContext.withContext(nested) {
        assert(OperationContext.current[TenantIDKey.self] == "tenant-456")
    }

    // The enclosing scope is unchanged.
    assert(OperationContext.current[TenantIDKey.self] == "tenant-123")
}
```

Binding a fresh `OperationContext()` clears every entry for that scope. Assigning `nil` through
the subscript removes a single entry from a copy.

#### Give your library a typed accessor

The library that owns a value defines its key. Keep the key internal and add an accessor when
other modules should be able to read the value but only your module should set it:

```swift
extension OperationContext {
    public internal(set) var tenantID: String? {
        get { self[TenantIDKey.self] }
        set { self[TenantIDKey.self] = newValue }
    }
}

// In any module:
let tenantID = OperationContext.current.tenantID
```

Expose a public key or a binding method instead when other packages legitimately need to establish
the value.

#### Cross a propagation boundary

Structured child tasks (`async let`, task groups) inherit the context and finish within the
operation's lifetime. An unstructured `Task { ... }` also inherits it but can outlive the scope
that created it. `Task.detached { ... }` starts with an empty context, so capture and rebind
explicitly:

```swift
let task = OperationContext.withContext(context) {
    let captured = OperationContext.current
    return Task.detached {
        OperationContext.withContext(captured) {
            OperationContext.current[TenantIDKey.self]
        }
    }
}

let detachedTenantID = await task.value
assert(detachedTenantID == "tenant-123")
```

Framework callbacks need the same capture-and-rebind. Network calls and durable jobs need explicit
encoding and validation of the values they carry; the package does neither automatically.
Synchronous code can use the synchronous `withContext` overload or take a context as a parameter.

## 📘 Documentation

- [API Documentation](https://swiftpackageindex.com/swift-microservices/swift-operation-context/documentation)
  — the complete reference, hosted on Swift Package Index.
  - [OperationContext](https://swiftpackageindex.com/swift-microservices/swift-operation-context/documentation/operationcontext)
    — the guide: defining keys, extending scopes, asynchronous operations, propagation boundaries,
    library-owned keys, and keeping domain behavior in consumers.
  - [`OperationContext`](https://swiftpackageindex.com/swift-microservices/swift-operation-context/documentation/operationcontext/operationcontext)
    — the container, `current`, and `withContext(_:operation:)`.
  - [`OperationContextKey`](https://swiftpackageindex.com/swift-microservices/swift-operation-context/documentation/operationcontext/operationcontextkey)
    — the key protocol.

Packages built on this one:

- [swift-authentication](https://github.com/swift-microservices/swift-authentication) — binds the
  caller's principal in the context for the length of a call, with transport integrations for
  [gRPC](https://github.com/swift-microservices/swift-authentication-grpc) and
  [Hummingbird](https://github.com/swift-microservices/swift-authentication-hummingbird).
- [swift-persistence-postgres](https://github.com/swift-microservices/swift-persistence-postgres)
  — reads per-operation Postgres settings from the context.

## 🧰 Release Info

- Versioning: [Semantic Versioning](https://semver.org). The public API is stable from 1.0.0 and
  only a major release breaks it; CI checks every pull request for API breakage.
- Release notes: [GitHub Releases](https://github.com/swift-microservices/swift-operation-context/releases).
- Swift versions: CI tests Swift 6.3, 6.4, and nightly toolchains on Linux (x86_64 and aarch64,
  plus the static Linux SDK).

## 🛠️ Support

If you have any questions or need help, feel free to reach out by [opening an
issue](https://github.com/swift-microservices/swift-operation-context/issues).

Contributions are welcome. Keep pull requests focused, include a test for the behavior you change,
and label each one with its semantic-version impact (`semver/none`, `semver/patch`,
`semver/minor`, or `semver/major`).

### Development

```bash
swift test
swift-format lint --strict --recursive Package.swift Sources Tests    # what the soundness check runs
```

## License

MIT. See [LICENSE](LICENSE).
