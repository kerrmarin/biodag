// Copyright © 2019 kerrmarin. All rights reserved.

import Foundation

// Adapted from https://medium.com/@mvxlr/swift-memoize-walk-through-c5224a558194
func memoize<T: Hashable, U>(_ closure: @escaping (T) -> U) -> (T) -> U {
    var cache = [T: U]()
    return { (val: T) -> U in
        if let value = cache[val] {
            return value
        }
        let newValue = closure(val)
        cache[val] = newValue
        return newValue
    }
}
