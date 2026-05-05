//
//  Biodag
//  A Swift micro-library that provides lightweight dependency injection.
//
//  Inspired by:
//  https://dagger.dev
//  https://github.com/hmlongco/Resolver
//  https://github.com/InsertKoinIO/koin
//
//  Created by Basem Emara on 2019-09-06.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation

/// A dependency collection that provides resolutions for object instances.
final public class DependencyResolver: @unchecked Sendable {
    private let lock = NSLock()
    private let moduleArray: [Module]
    /// Stored object instance factories.
    private var modules = [String: Module]()
    private var instances = [String: Any]()

    /// Construct dependency resolutions.
    public init(@ModuleBuilder _ modules: () -> [Module]) {
        self.moduleArray = modules()
    }

    /// Construct dependency resolution.
    public init(@ModuleBuilder _ module: () -> Module) {
        self.moduleArray = [module()]
    }

    /// Assigns the current container to the composition root.
    public func build() {
        for module in moduleArray {
            Self.root.add(module: module)
        }
    }

    fileprivate init() {
        self.moduleArray = []
    }
}

// SAFETY: DependencyResolver uses an NSLock to synchronize all access to mutable state
// (modules and instances dictionaries). All mutations are protected by the lock.

private extension DependencyResolver {
    /// Composition root container of dependencies.
    static let root = DependencyResolver()

    /// Registers a specific type and its instantiating factory.
    func add(module: Module) {
        lock.withLock {
            self.modules[module.name] = module
            // When we register a new module, if there is an instance with the same name we remove it
            self.instances[module.name] = nil
        }
    }
}

public extension DependencyResolver {
    /// Resolves through inference and returns an instance of the given type from the current default container.
    ///
    /// If the dependency is not found, an exception will occur.
    func resolve<T>(for name: String? = nil) -> T {
        let name = name ?? String(describing: T.self)

        return lock.withLock {
            // First, make sure the module is available
            guard let module = modules[name] else {
                fatalError("Module '\(T.self)' not found!")
            }

            // Second, resolve the module as a dependency. If the module was registered as a
            // prototype, return the resolved instance.
            // If the module was registered as a singleton, return the cached instance if it exists,
            // or the resolved one after storing it in the dependency resolver.
            let component: T = {
                // Create a closure to lazily evaluate the resolution of the module
                let resolvedModuleClosure: () -> T = {
                    guard let mod = module.resolveValue() as? T else {
                        fatalError("Dependency '\(T.self)' not resolved!")
                    }
                    return mod
                }

                switch module.scope {
                case .prototype:
                    return resolvedModuleClosure()
                case .singleton:
                    if let instance = instances[name] as? T {
                        return instance
                    }
                    let resolvedModule = resolvedModuleClosure()
                    instances[name] = resolvedModule
                    return resolvedModule
                }
            }()

            return component
        }
    }

    /// Resolves using the shared composition root (same behavior as ``Inject``).
    ///
    /// Use this when you need concurrent or non-instance resolution without capturing ``Inject``'s
    /// property-wrapper storage (e.g. tests or advanced wiring).
    static func resolveFromSharedRoot<T>(for name: String? = nil) -> T {
        Self.root.resolve(for: name)
    }
}

// MARK: Public API

public extension DependencyResolver {

    /// DSL for declaring modules within the container dependency initializer.
    @resultBuilder struct ModuleBuilder {
        public static func buildBlock(_ modules: Module...) -> [Module] { modules }
        public static func buildBlock(_ module: Module) -> Module { module }
    }
}

// SAFETY: Holds a non-Sendable factory so `Module` can capture @MainActor / non-Sendable values (e.g. UI adapters).
// The factory runs only while `DependencyResolver`'s lock is held during `resolve` / registration paths; see THREAD_SAFETY.md.
private final class ModuleFactoryBox: @unchecked Sendable {
    private let run: () -> Any

    init<T>(_ factory: @escaping () -> T) {
        self.run = { factory() as Any }
    }

    func resolve() -> Any {
        self.run()
    }
}

/// A type that contributes to the object graph.
public struct Module: Sendable {
    fileprivate let name: String
    fileprivate let factory: ModuleFactoryBox
    fileprivate let scope: InjectionScope

    /// - Parameter resolve: Factory for this dependency. May capture non-Sendable or main-actor state; callers must ensure
    ///   it is safe to run from threads that invoke `DependencyResolver.resolve` or `Inject.wrappedValue` (see THREAD_SAFETY.md).
    public init<T>(_ name: String? = nil, scope: InjectionScope = .prototype, _ resolve: @escaping () -> T) {
        self.name = name ?? String(describing: T.self)
        self.factory = ModuleFactoryBox(resolve)
        self.scope = scope
    }

    fileprivate func resolveValue() -> Any {
        self.factory.resolve()
    }
}

/// Resolves an instance from the dependency injection container.
@propertyWrapper
public struct Inject<Value>: @unchecked Sendable {
    private let name: String?
    private let resolutionClosure: (String?) -> Value

    public var wrappedValue: Value {
        return self.resolutionClosure(self.name)
    }

    public init() {
        self.name = nil
        self.resolutionClosure = memoize { name -> Value in
            return DependencyResolver.root.resolve(for: name)
        }
    }

    public init(_ name: String) {
        self.name = name
        self.resolutionClosure = memoize { _ -> Value in
            return DependencyResolver.root.resolve(for: name)
        }
    }
}

public enum InjectionScope: Sendable {
    case singleton
    case prototype
}
