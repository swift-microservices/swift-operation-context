// Copyright (c) 2026 Zaid Rahhawi
// SPDX-License-Identifier: MIT
// See LICENSE for license information.

/// A key whose type uniquely identifies a value in an ``OperationContext``.
///
/// Declare a separate key type for each independent value. Keys with the same `Value` type
/// remain distinct, as do different specializations of a generic key. The library that owns
/// a value defines its key and can add a typed accessor to `OperationContext`. Prefer private or
/// internal keys when an accessor should restrict who can replace the value. Expose keys
/// or binding methods when other packages legitimately need to establish that value.
///
/// `SendableMetatype` permits key types and their conformances to cross isolation boundaries.
/// Key instances are never stored and need not be `Sendable`; stored values must be.
///
/// ```swift
/// enum TenantIDKey: OperationContextKey {
///     typealias Value = String
/// }
///
/// var context = OperationContext()
/// context[TenantIDKey.self] = "tenant-123"
/// ```
public protocol OperationContextKey: SendableMetatype {
    /// The Sendable value type stored under this key.
    ///
    /// This type may itself be optional. The context's subscript adds an outer optional
    /// to distinguish an absent entry from a stored value.
    associatedtype Value: Sendable
}
