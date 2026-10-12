# ``OperationContext``

Propagate typed values through synchronous and asynchronous operations.

## Overview

An operation context carries values through a request, background job, or other unit of work.
Libraries define their own keys and can share one context without depending on each other's
domain types. The package provides typed storage and scoped propagation with no external
dependencies or Foundation imports.

### Define a key and bind a context

Declare a type conforming to ``OperationContextKey`` and choose a `Sendable` value type.
Populate a context and bind it with `OperationContext.withContext(_:operation:)`:

```swift
import OperationContext

enum TenantIDKey: OperationContextKey {
    typealias Value = String
}

var context = OperationContext()
context[TenantIDKey.self] = "tenant-123"

let tenantID = OperationContext.withContext(context) {
    OperationContext.current[TenantIDKey.self]
}

assert(tenantID == "tenant-123")
assert(OperationContext.current[TenantIDKey.self] == nil)
```

`OperationContext.current` defaults to an empty context. The subscript returns `nil` for an
unset key. Key identity depends on the key's type, including generic specialization, rather
than its name or associated value type. Two keys with the same `Value` type remain independent.

### Extend an existing scope

`withContext` replaces the complete binding for the duration of its closure. To preserve
existing values, copy the current context before changing it:

```swift
OperationContext.withContext(context) {
    var nested = OperationContext.current
    nested[TenantIDKey.self] = "tenant-456"

    OperationContext.withContext(nested) {
        assert(OperationContext.current[TenantIDKey.self] == "tenant-456")
    }

    assert(OperationContext.current[TenantIDKey.self] == "tenant-123")
}
```

Use a new `OperationContext()` at the start of an independent operation. Binding an empty
context temporarily clears all entries; contexts are never merged automatically. Removing an
entry from a copied context affects only that copy. Stored reference values are shared according
to their own `Sendable` semantics and are not deep-copied.

### Use asynchronous operations

The asynchronous overload keeps the caller's actor isolation across suspension and permits
non-Sendable captures and results that are valid in that isolation context:

```swift
let asyncTenantID = try await OperationContext.withContext(context) {
    try Task.checkCancellation()
    await Task.yield()
    return OperationContext.current[TenantIDKey.self]
}

assert(asyncTenantID == "tenant-123")
```

Both overloads return the operation's result and propagate its error unchanged. They restore
the enclosing binding when the operation returns or throws. The asynchronous overload runs
in the existing task without changing or automatically checking its cancellation state.
If the operation throws `CancellationError`, the same restoration applies.

The library enables `NonisolatedNonsendingByDefault` to preserve caller isolation. Consumers
do not need to enable that feature in their own targets to use this API.

### Understand propagation boundaries

Automatic propagation uses Swift concurrency's task-local values. Prefer structured child tasks,
created with `async let` or task groups, to inherit the binding and keep child work within the
operation's lifetime. Unstructured `Task { ... }` also inherits the binding, but may retain it
after its creating scope has exited. Restoring the parent's binding does not revoke values
already inherited by another task.

Detached tasks start with an empty context. Capture and rebind explicitly when the detached
work should receive the context:

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

Framework callbacks and event-loop futures require their own capture-and-rebind adapters.
Network calls and durable jobs require explicit encoding and validation of selected values.
The package does not perform either integration automatically.

The `current` task local and its `$current` projection are public. Direct binding through
`OperationContext.$current.withValue` uses Swift's task-local API.

### Design library-owned keys

Define a key in the library that owns the value. Keep the key private or internal when callers
should use a typed accessor with controlled write access:

```swift
extension OperationContext {
    public internal(set) var tenantID: String? {
        get { self[TenantIDKey.self] }
        set { self[TenantIDKey.self] = newValue }
    }
}
```

With the internal key above, other modules can read `current.tenantID`, while only the defining
module can set it. Expose a public key or a domain-specific binding method when other libraries
need to establish a value. Keys inherit `SendableMetatype`; their instances are never stored
and do not need to be `Sendable`.

Assigning `nil` to the subscript removes an entry. When `Key.Value` is optional, use `.some(nil)`
to store a present optional value whose contents are `nil`. Reading that entry returns the
outer `.some` case; reading a missing entry returns the outer `.none` case.

### Keep domain behavior in consumers

Identity, credentials, and transaction settings can use separate keys in the same context.
Consumers remain responsible for authentication, authorization, credential lifetime, and the
application of database settings and row-level security policies. At an independent request
or job boundary, establish a fresh context and validate the caller explicitly.

The package has no built-in authentication, database, serialization, or instrumentation
integration. Choose values for telemetry explicitly and keep credentials out of diagnostic
output. Access control on keys and accessors controls API usage; it does not enforce domain
security policies.

## Topics

### Context storage and scoping

- ``OperationContext/OperationContext``

### Typed keys

- ``OperationContextKey``
