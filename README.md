# Swift Operation Context

`OperationContext` is a lightweight, zero-dependency container for propagating typed values
between Swift tasks and functions. Libraries can use it to carry identity, credentials, or
database settings without depending on each other's domain types.

## Overview

Start with an empty `OperationContext()` for a new operation, or copy `OperationContext.current`
to extend an existing one. Each key conforms to `OperationContextKey` and defines a `Sendable`
value type. The context is a value type; changing a copy leaves the original container unchanged.

Bind a context with `withContext(_:operation:)` to make its values available throughout an
operation and its structured child tasks:

```swift
import OperationContext

enum TenantIDKey: OperationContextKey {
    typealias Value = String
}

func readTenantID() async -> String? {
    OperationContext.current[TenantIDKey.self]
}

var context = OperationContext()
context[TenantIDKey.self] = "tenant-123"

let tenantID = await OperationContext.withContext(context) {
    async let inheritedTenantID = readTenantID()
    return await inheritedTenantID
}

assert(tenantID == "tenant-123")
assert(OperationContext.current[TenantIDKey.self] == nil)
```

`current` defaults to an empty context, and reading an unset key returns `nil`. Both synchronous
and asynchronous `withContext` overloads restore the previous binding when the operation returns
or throws. They bind the supplied context without merging it with the enclosing context.

## Swift concurrency

Automatic propagation relies on Swift concurrency's task-local values. Use structured concurrency,
including `async let` and task groups, to inherit the context while keeping child work within the
operation's lifetime. The asynchronous `withContext` overload preserves caller actor isolation
and runs in the existing task.

Unstructured `Task { ... }` also inherits the context, but can outlive the scope that created it.
`Task.detached { ... }` does not inherit it. Detached work and framework callbacks need explicit
capture and rebinding; network calls require explicit serialization. Synchronous code can also
use the scoped API or pass a context directly.

## Dependency

Requires Swift 6.3 or later. Supported platforms are Linux and macOS 15 or later.

Add the package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/swift-microservices/swift-operation-context.git", from: "0.1.0")
```

Add the product to your target's dependencies:

```swift
.product(name: "OperationContext", package: "swift-operation-context")
```

## Documentation

See the [DocC documentation](Sources/OperationContext/Documentation.docc/OperationContext.md)
for key design, nested scopes, and propagation boundaries. Authentication, authorization, and
database policy enforcement belong to consuming libraries; this package provides value propagation.

## License

MIT. See [LICENSE](LICENSE).
