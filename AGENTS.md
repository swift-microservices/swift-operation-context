# Repository guidelines

This package provides typed, scoped value propagation shared by independent libraries.

- One product and module, `OperationContext`, exporting `OperationContext` and `OperationContextKey`.
- No external dependencies, Foundation imports, authentication types, database settings,
  transport integrations, instrumentation hooks, serialization, or global mutable registries.
- Keys are identified by type, including generic specialization. `OperationContextKey` inherits
  `SendableMetatype`; instances need not be Sendable. Only the typed subscript writes storage;
  its internal cast relies on that invariant. Values must be `Sendable`.
- Scope with Swift task locals. Keep sync and async overloads, nonoptional `current` defaulting
  to an empty context, public `init()`, and nested restoration. Clear a scope by binding
  `OperationContext()`; individual entries remain optional. Do not automatically merge contexts.
- Keep `@TaskLocal public static var current` and its public `$current` projection. This is
  an explicit API choice; do not hide the backing task local.
- Preserve caller actor isolation, non-Sendable captures and results, error identity, and
  cancellation. Do not spawn tasks inside `withContext` or require a `@Sendable` closure.
- The container has value semantics; stored references are not deep-copied.
- Tests use Swift Testing and cover concurrent propagation and isolation contracts. Do not
  replace these with tests that only verify dictionary insertion and lookup.
- Swift 6.3, Swift 6 language mode, and the four shared upcoming features on every target.
- Document public API and keep README and DocC consistent. Use the checked-in `.swift-format`
  and compact MIT header; run tests, strict formatting, and a release build.
  PR soundness CI checks documentation. Keep tests focused on the package's public contracts;
  do not add custom verification scripts or intentionally invalid compiler fixtures.
- Never commit `Package.resolved`. Consumers depend on published tags. Do not describe local
  checks as successful Linux CI.
- Keep CI aligned with the other swift-microservices libraries: shared Linux tests/builds
  for Swift 6.3/6.4 and snapshots, PR soundness, static SDK builds, Foundation-linking checks,
  SemVer labels, and manual releases. The DocC target is `OperationContext`.
- macOS 15 is the deliberate supported runtime baseline; Linux CI uses Ubuntu 24.04.
  No support guarantee for other Apple OSes or older macOS. See README platform requirements.
- Each PR uses exactly one SemVer label. Auto Release is manually triggered on main after
  a remote exists. Do not create a remote, publish, or release without user authorization.
