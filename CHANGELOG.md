# Unreleased

- Relax `Module` factory type to `@escaping () -> T` (no longer requires `@Sendable`), enabling registration that captures `@MainActor` or non-Sendable instances (for example app adapters).
- Store module factories in an internal `@unchecked Sendable` box; document caller obligations in `THREAD_SAFETY.md`.
- `Inject` is now `@unchecked Sendable`; `memoize` returns `(T) -> U` by default, with a `@Sendable` overload (marked `@_disfavoredOverload`) for use in `DispatchQueue.async` and similar APIs.
- Add `DependencyResolver.resolveFromSharedRoot(for:)` for resolving via the shared root without `@Inject` property-wrapper storage.
- Tests: resolve concurrently via `resolveFromSharedRoot`; add `testModuleFactoryCapturesMainActorInstance`.

# 0.5.0
- Update swift-tools-version to 6.2
- Maintain Swift 6.0 language mode with strict concurrency checking
- Add Sendable conformance to DependencyResolver, Module, Inject, and InjectionScope
- Implement thread-safe access to DependencyResolver with NSLock
- Add thread-safe memoization cache with MemoizeCache
- Mark closure types as @Sendable to satisfy concurrency requirements

# 0.4.0
- Update Swift version to 5.10
- Allow multiple modules to be registered at different times

# 0.3.0
- Update @_functionBuilder to @resultBuilder
- Update Swift version to 5.4

# 0.1.0 - 0.2.0
 - Changes not recorded
