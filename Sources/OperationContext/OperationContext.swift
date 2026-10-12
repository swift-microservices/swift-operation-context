// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

/// Typed values made available while performing a logical unit of work.
///
/// Libraries define their own ``OperationContextKey`` types without coupling this package to their
/// domains. A context can be passed explicitly or bound with `withContext(_:operation:)`.
/// Copy the current context before changing it to preserve values established by enclosing scopes.
/// Changes to the copied container do not change its parent; stored reference values retain
/// their own sharing semantics and must be `Sendable`.
/// An operation can be a request, a job, or local work spanning several calls and transactions.
/// The context does not create a task, control a transaction, or propagate across a network.
public struct OperationContext: Sendable {
    private var values: [ObjectIdentifier: any Sendable] = [:]

    /// Creates an empty context for an independent operation.
    ///
    /// To extend an existing operation instead, copy ``current`` and modify the copy.
    public init() {}

    /// The context bound to this task, defaulting to an empty context.
    ///
    /// Reading a missing entry returns `nil`. Copy this context before changing its entries,
    /// then bind the copy with `withContext(_:operation:)` to establish a nested scope.
    ///
    /// Child tasks and `Task { ... }` inherit the binding when created. An unstructured task
    /// can retain that binding after its creating scope exits. Detached tasks start with an
    /// empty context. Framework callbacks and network boundaries require explicit propagation.
    /// The public `$current` projection also supports binding through Swift's task-local API.
    @TaskLocal public static var current = OperationContext()

    /// Reads or replaces the value for `key`; assigning `nil` removes the entry.
    ///
    /// Only a value of `Key.Value` can be stored under a particular key type. If `Key.Value`
    /// is itself optional, assign `.some(nil)` to store a present optional value of `nil`.
    /// Changing an entry affects only this context, not previously created copies.
    ///
    /// - Parameter key: The type identifying the entry to read or replace.
    /// - Returns: The stored value, or `nil` if the key has no entry.
    public subscript<Key: OperationContextKey>(_ key: Key.Type) -> Key.Value? {
        get {
            guard let value = values[ObjectIdentifier(key)] else { return nil }
            // Storage is private and this typed setter is its only write path.
            return (value as! Key.Value)
        }
        set {
            if let newValue {
                values[ObjectIdentifier(key)] = newValue
            } else {
                values.removeValue(forKey: ObjectIdentifier(key))
            }
        }
    }

    /// Runs a synchronous operation with `context` bound, restoring the previous binding afterward.
    ///
    /// The supplied context replaces the complete binding; entries are not merged. Copy
    /// ``current`` first to preserve existing entries, or pass `OperationContext()` to clear
    /// them for the scope. The previous binding is restored when the operation returns or throws.
    ///
    /// - Parameters:
    ///   - context: The complete context to make current during the operation.
    ///   - operation: A nonescaping closure to execute with the context bound.
    /// - Returns: The result of `operation`.
    /// - Throws: The error thrown by `operation`, unchanged.
    public static func withContext<Result>(
        _ context: Self,
        operation: () throws -> Result
    ) rethrows -> Result {
        try $current.withValue(context, operation: operation)
    }

    /// Runs an asynchronous operation with `context` bound, restoring the previous binding afterward.
    ///
    /// The supplied context replaces the complete binding; entries are not merged. Copy
    /// ``current`` first to preserve existing entries, or pass `OperationContext()` to clear
    /// them for the scope. The previous binding is restored when the operation returns or throws.
    ///
    /// The operation keeps the caller's actor isolation across suspension and may capture or
    /// return non-Sendable values that are valid in that isolation context. It runs in the
    /// existing task without changing or automatically checking its cancellation state.
    /// Restoration also applies when the operation throws `CancellationError`.
    ///
    /// - Parameters:
    ///   - context: The complete context to make current during the operation.
    ///   - operation: A nonescaping asynchronous closure to execute with the context bound.
    /// - Returns: The result of `operation`.
    /// - Throws: The error thrown by `operation`, unchanged.
    public static func withContext<Result>(
        _ context: Self,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await $current.withValue(context) {
            try await operation()
        }
    }
}
