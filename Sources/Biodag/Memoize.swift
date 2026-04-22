// Copyright © 2019 kerrmarin. All rights reserved.

import Foundation

// MARK: - Thread-safe memoization cache

/// A thread-safe cache for memoized values.
final class MemoizeCache<Key: Hashable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [Key: Value] = [:]

    func value(for key: Key, compute: @Sendable (Key) -> Value) -> Value {
        lock.withLock {
            if let cached = cache[key] {
                return cached
            }
            let computed = compute(key)
            cache[key] = computed
            return computed
        }
    }
}

// SAFETY: MemoizeCache uses an NSLock to synchronize all access to the cache dictionary.
// All reads and writes are protected by the lock, ensuring thread-safe access.

// Adapted from https://medium.com/@mvxlr/swift-memoize-walk-through-c5224a558194
public func memoize<T: Hashable & Sendable, U>(_ closure: @escaping @Sendable (T) -> U) -> @Sendable (T) -> U {
    let cache = MemoizeCache<T, U>()
    return { @Sendable (val: T) -> U in
        cache.value(for: val, compute: closure)
    }
}
