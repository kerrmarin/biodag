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
final public class DependencyResolver {
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

private extension DependencyResolver {
    /// Composition root container of dependencies.
    static let root = DependencyResolver()

    /// Registers a specific type and its instantiating factory.
    func add(module: Module) {
        self.modules[module.name] = module
        // When we register a new module, if there is an instance with the same name we remove it
        self.instances[module.name] = nil
    }

    /// Resolves through inference and returns an instance of the given type from the current default container.
    ///
    /// If the dependency is not found, an exception will occur.
    func resolve<T>(for name: String? = nil) -> T {
        let name = name ?? String(describing: T.self)
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
                guard let mod = module.resolve() as? T else {
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

// MARK: Public API

public extension DependencyResolver {

    /// DSL for declaring modules within the container dependency initializer.
    @resultBuilder struct ModuleBuilder {
        public static func buildBlock(_ modules: Module...) -> [Module] { modules }
        public static func buildBlock(_ module: Module) -> Module { module }
    }
}

/// A type that contributes to the object graph.
public struct Module {
    fileprivate let name: String
    fileprivate let resolve: () -> Any
    fileprivate let scope: InjectionScope

    public init<T>(_ name: String? = nil, scope: InjectionScope = .prototype, _ resolve: @escaping () -> T) {
        self.name = name ?? String(describing: T.self)
        self.resolve = resolve
        self.scope = scope
    }
}

/// Resolves an instance from the dependency injection container.
@propertyWrapper
public struct Inject<Value> {
    private let name: String?
    private let resolutionClosure = memoize { name -> Value in
        return DependencyResolver.root.resolve(for: name)
    }

    public var wrappedValue: Value {
        return self.resolutionClosure(self.name)
    }

    public init() {
        self.name = nil
    }

    public init(_ name: String) {
        self.name = name
    }
}

public enum InjectionScope {
    case singleton
    case prototype
}
